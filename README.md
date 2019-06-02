# 记录匹配


## 目录
1. [背景](#background)  
2. [安装](#installation)  
3. [准备工作](#prep)  
4. [使用方法](#usage)  
5. [结果解读](#interpret)



<a name="background"></a>
## 1. 背景
在信息录入过程中，因为从纸质文本到电子信息的转录错误（例如报告病例姓名过于潦草），以及在电子信息输入过程中的错误（例如王方和王芳），同一个人在大疫情中的记录的姓名，性别，出生年月及其他信息可能并不完全一致，这就会给后续的数据处理及数据分析过程带来困难。例如在分析乙肝报告病例过程中，由于目前乙肝并无法治愈，所以在计算发病率的过程中，应该排除以前报告过的病例，但是如果该次报告的病人姓名和之前的记录中并不完全一致时，使用精确匹配就无法准确的识别出之前报告过的记录。

现有的记录匹配算法多基于英文文本开发，对于中文来讲并不适用。对于中文人名来讲，首先名字大多只包括2-4个汉字，如果像英文人名一样，仅考虑字符之间的[编辑距离相似度](https://www.cnblogs.com/ivanyb/archive/2011/11/25/2263356.html)，会给结果带来很大的偏差。例如，从程咬金到程幺金，编辑距离为1，编辑距离相似度为0.66，而从Charles到Chales，编辑距离为1，编辑距离相似性为0.86。由于中国人的命名习惯，兄弟姐妹的名字常只有一个汉字的差异，例如蒋经国和蒋纬国，宋庆龄和宋美龄，因此仅靠编辑距离相似度来进行中文记录匹配远远不够。其次，中文是象形文字，从汉字本身并不能知道读音，因此英文中常见的基于读音匹配的算法，例如[Soundex](https://riddickbryant.iteye.com/blog/561665)也并不能直接应用于汉字。

基于汉字以及中文人名的特点，我们改进了现有的记录匹配R包fastLink，将我们开发的利用机器学习方法xgboost来进行姓名匹配的方法融入fastLink中，该姓名匹配方法可以同时考虑汉字的读音（拼音），字形（五笔和四角号码），偏旁部首及结构。除了姓名，在记录匹配中还可以同时考虑其他的属性，例如性别，出生年月，地址等。本文档将介绍fastLink包的安装方法，使用方法以及结果解读。



<a name="installation"></a>
## 2. 安装
1. [安装R及RStudio](https://blog.csdn.net/Joshua_HIT/article/details/73741139)。Rstudio的使用见[R语言初级教程](https://zhuanlan.zhihu.com/p/45503712)。
2. [安装Rtools](https://www.cnblogs.com/liugh/p/9937489.html)-只需要步骤一和二，即安装和设置环境变量
3. [安装所需要的R包](http://blog.sciencenet.cn/blog-2379401-936653.html)tidyverse, xgboost和devtools，可按照链接中的方法1来安装，即在RStudio的操作台中输入install.packages("tidyverse")，之后回车。另外两个包可以按照同样的方法安装。 
4. 使用以下代码安装Berkeley开发的包chinsimi, fastLink。
```
devtools::install_github('OPTI-SURVEIL/fastLink',dependencies = T, force = TRUE)
devtools::install_github('OPTI-SURVEIL/chinsimi',dependencies = T, force = TRUE)
```



<a name="prep"></a>
## 3. 准备工作
1. 下载[此文件夹](https://github.com/OPTI-SURVEIL/RLManual)中除了README.md的所有文件，其中：
* Name match 1.csv和Name match 2.csv为样例数据
* linkage_utils.R为匹配过程中需要的函数
* isotonic_regs.Rdata以及F-score_based_thresholds.Rdata为机器学习模型


2. 将系统环境设置为中文。因为我们需要匹配的记录是中文，因此我们需要首先将R环境设置成中文。
```
Sys.setlocale(category = 'LC_ALL', locale = 'Chinese')
```


3. 设置工作文件夹为保存步骤1中下载数据的文件夹，注意文件路径中应该用"/"而非"\"，例如不应该用"C:\Users\Documents\"而应该用"C:/Users/Documents/"。 例如：
```
setwd("C:/Users/Documents/")
```
将C:/Users/Documents/替换为第1步中保存下载数据的路径


4. 加载所需要的R包
```
library(tidyverse)
library(fastLink)
library(ChinSimi)
library(xgboost)
```


5. 导入包括所需要的函数的R文件linkage_utils.R（在步骤1中已经下载）
```
source('linkage_utils.R')
```


6. 导入姓名匹配机器学习模型数据
```
load('final_xgb_model_10.Rdata')
load('F-score_based_thresholds.Rdata')
```



<a name="usage"></a>
## 4. 使用方法
1. 导入数据

fastLink包采用Fellegi-Sunter记录匹配法，方法详细描述见[此文章](https://imai.fas.harvard.edu/research/files/linkage.pdf)。包中主要使用函数为fastLink()和getMatches()。fastLink()用于进行匹配，getMatches()用于提取相匹配的记录。
首先读取数据，以下为读取示例数据，其中S1为需要匹配的数据1，S2为需要匹配的数据2，以下为使用之前下载的示例数据。正确的匹配结果为S1中的1-100行分别与S2中的1-100行一一对应。**注意：**需要设置stringAsFactors = FALSE，不然姓名会作为factor读入而非字符串，后续匹配过程将会报错。
```
S1 <- read.csv("Name match 1.csv", stringsAsFactors = FALSE)
S2 <- read.csv("Name match 2.csv", stringsAsFactors = FALSE)
```
通过下列命令，可以查看S1和S2都包含哪些数据
```
View(S1)
View(S2)
```
以下为S1的前6行：
```
        name sex  yob mob dob
1       孙文   0 1975   6   1
2       莊子   1 1980  10  17
3 伊姆荷太普   1 1993   4   6
4     神农氏   1 1983  11   9
5     陈水扁   0 1977   9   6
6     拿破仑   1 1958   8  19
```
以下为S2的前6行:
```
        name sex  yob mob dob
1     孫中山   0 1975   6   1
2       庄子   1 1980  10  17
3     印何闐   1 1993   4   6
4       神农   1 1983  11   9
5     陳水扁   0 1977   9   6
6 拿破仑一世   1 1958   8  19
```
其中name字段为姓名, sex字段为性别（随机生成，不代表真实性别），yob为出生年份，mob为出生月份，dob为出生日期（随机生成，不代表真实出生日期）。NA表示该字段数据缺失。


2. 记录匹配

记录匹配使用fastLink()函数，在R操作台中，输入?fastLink可以查看函数的使用说明
```
valres = fastLink(dfA = S1, dfB = S2, varnames = c('name','sex','yob','mob','dob'),
                   stringdist.match = 'name', stringdist.method = chin_strsim,
                   stringdist.args = list(model = model_10, reftable = unique(S1$name, S2$name)),
                   string.transform = transparser, 
                   string.transform.args = list(model = model_10,reftable = unique(S1$name, S2$name)),
                   cut.a = xgb10_thresh, verbose = T,estimate.only = F,cond.indep = F)
```
* dfA表示第一个需要匹配的记录集，dfB表示第二个需要匹配的记录集，这里因为我们在读入数据时，给数据集的命名为S1和S2，因此输入时，设置dfA = S1, dfB = S2。在实际操作中，需要根据你在读入数据时使用的数据集名称来设置。需要注意的是，在S1和S2中，请使用一致的字段名，并且最好使用英文字段名。例如，如果姓名字段在S1中的名称为xingming，那么在S2中也应该保持一致，而不能使用name。

* varnames代表需要用来进行匹配的字段。在S1和S2中，我们用所有的5个字段，即name, sex, yob, mob和dob来进行匹配。stringdist.match表示需要利用我们的中文匹配方法来进行匹配的字段，即通过拼音，四角号码，五笔，偏旁部首，字型结构以及它们的组合来进行匹配，在这里我们仅对name字段进行中文字符串匹配。在实际操作中，请设置成你所需要进行姓名匹配的字段名称。

* stringdist.method表示计算姓名相似性的函数，该函数的返回值为代表S1和S2中每个元素的相似性的矩阵。这里使用的是chin_strsim函数。**请不要修改此参数。**

* stringdist.args表示输入chin_strsim函数的参数，请将reftable = unique(S1$name, S2$name)中的S1, S2分别替换为你所使用的dfA和dfB的名字，name替换为你所使用的进行姓名匹配的字段名称。

* string.transform表示用来生成拼音，四角号码，五笔，偏旁部首，字型结构以及它们的组合的函数。这里使用的是transparser函数。**请不要修改此参数。**

* string.transform.args表示输入给transparser函数的参数，同上请将reftable = unique(S1$name, S2$name)中的S1, S2分别替换为你所使用的dfA和dfB的名字，name替换为你所使用的进行姓名匹配的字段名称。

* cut.a表示在判断姓名是否匹配的时候的相似性的阈值，这里通过机器学习方法xgboost得到。**请不要修改此参数。**

* verbose表示是否显示匹配进度，设为T时表示是，设为F时表示否。

* estimate.only表示是否只输出参数，不输出匹配结果，设为T时表示是，即仅输出模型的参数，建议设为F，则可同时输出参数和匹配结果。

* cond.indep表示是否假设条件独立，建议设为F


在匹配过程中，会输出以下信息，请
```
==================== 
fastLink(): Fast Probabilistic Record Linkage
==================== 

If you set return.all to FALSE, you will not be able to calculate a confusion table as a summary statistic.
Calculating matches for each variable.
    Matching variable name using string-distance matching.
WARNING: You have no exact matches for name.
    Matching variable sex using exact matching.
    Matching variable yob using exact matching.
    Matching variable mob using exact matching.
    Matching variable dob using exact matching.
Calculating matches for each variable took 0.7 minutes.

Getting counts for parameter estimation.
    Parallelizing calculation using OpenMP. 1 threads out of 8 are used.
Getting counts for parameter estimation took 0 minutes.

Running the EM algorithm.
Running the EM algorithm took 0.29 seconds.

** Selected match probability threshold is:  0.254680688264359 **
Getting the indices of estimated matches.
    Parallelizing calculation using OpenMP. 1 threads out of 8 are used.
Getting the indices of estimated matches took 0 minutes.

Deduping the estimated matches.
Deduping the estimated matches took 0 minutes.

Getting the match patterns for each estimated match.
Getting the match patterns for each estimated match took 0 minutes.

```

3. 提取匹配记录


<a name="interpret"></a>
## 5. 结果解读
