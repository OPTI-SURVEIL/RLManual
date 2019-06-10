# 记录匹配


## 目录
1. [背景](#background)  
2. [安装](#installation)  
3. [准备工作](#prep)  
4. [使用方法](#usage)  



<a name="background"></a>
## 1. 背景
在信息录入过程中，因为从纸质文本到电子信息的转录错误（例如报告病例姓名过于潦草），以及在电子信息输入过程中的错误（例如王方和王芳），同一个人在大疫情中的记录的姓名，性别，出生年月及其他信息可能并不完全一致，这就会给后续的数据处理及数据分析过程带来困难。例如在分析乙肝报告病例过程中，由于目前乙肝无法治愈，所以在计算发病率的过程中，应该排除以前报告过的病例，但是如果该次报告的病人姓名和之前的记录中并不完全一致时，使用精确匹配就无法准确的识别出之前报告过的记录。在这种情况下，可以使用模糊匹配或者概率匹配。当利用多个字段进行匹配时，可以用概率匹配算法根据每个记录对中相匹配的字段组合（例如姓名相同，出生年月日相同，性别相同，地址不同）来计算这两个记录属于同一个人的概率。

改进姓名匹配的定义也可以改善记录匹配的结果。现有的姓名匹配算法多基于英文文本开发，对于中文来讲并不适用。对于中文人名来讲，首先名字大多只包括2-4个汉字，如果像英文人名一样，仅考虑字符之间的[编辑距离相似度](https://www.cnblogs.com/ivanyb/archive/2011/11/25/2263356.html)，会给结果带来很大的偏差。例如，从程咬金到程幺金，编辑距离为1，编辑距离相似度为0.66，而从Charles到Chales，编辑距离为1，编辑距离相似性为0.86。由于中国人的命名习惯，兄弟姐妹的名字常只有一个汉字的差异，例如蒋经国和蒋纬国，宋庆龄和宋美龄，因此仅靠编辑距离相似度来进行中文记录匹配远远不够。其次，中文是象形文字，从汉字本身并不能知道读音，因此英文中常见的基于读音匹配的算法，例如[Soundex](https://riddickbryant.iteye.com/blog/561665)也并不能直接应用于汉字，但是我们可以用拼音的相似性来反映读音的相似性。除了音近字以外，中文中还存在很多形近字，例如由、甲、田、申，在转录过程中很容易出错。字形的相似性可以通过两个字的五笔、四角号码、偏旁部首以及字形结构的相似性来反映。

基于汉字以及中文人名的特点，我们改进了现有的记录匹配R包fastLink，将我们开发的利用机器学习方法xgboost来进行姓名匹配的方法融入fastLink中，该姓名匹配方法可以同时考虑汉字的读音（拼音），字形（五笔和四角号码），偏旁部首及结构的编辑距离相似度，[余弦相似度](https://baike.baidu.com/item/%E4%BD%99%E5%BC%A6%E7%9B%B8%E4%BC%BC%E5%BA%A6/17509249?fr=aladdin)（对汉字顺序的颠倒不敏感）和最长公共子序列（对增字减字不敏感），并利用监督学习来利用多种相似度来判断两个姓名是否匹配。本包中提供的姓名匹配方法包括单一相似度（拼音，五笔，四角号码，偏旁部首分解），多种相似度的线性组合以及xgboost模型。除了姓名，在记录匹配中还可以同时考虑其他的属性，例如性别，出生年月，地址等。本文档将介绍改进后的fastLink包的安装方法，使用方法以及结果解读。



<a name="installation"></a>
## 2. 安装
1. [安装R及RStudio](https://blog.csdn.net/Joshua_HIT/article/details/73741139)。Rstudio的使用见[R语言初级教程](https://zhuanlan.zhihu.com/p/45503712)。

2. [安装Rtools](https://www.cnblogs.com/liugh/p/9937489.html)-只需要步骤一和二，即安装和设置环境变量

  Rtools可从https://pan.baidu.com/s/1Cot7btWJubv3NJ7iGRvwKQ 下载，提取码: 8dbp
  
3. [安装所需要的R包](http://blog.sciencenet.cn/blog-2379401-936653.html)tidyverse, xgboost,devtools和readr，可按照链接中的方法1来安装，即在RStudio的操作台中输入install.packages("tidyverse")，之后回车。另外两个包可以按照同样的方法安装。

4. 使用以下代码安装Berkeley开发的包chinsimi, fastLink。
```
devtools::install_github('OPTI-SURVEIL/fastLink',dependencies = T, force = TRUE)
devtools::install_github('OPTI-SURVEIL/chinsimi',dependencies = T, force = TRUE)
```

如果安装出现问题，请尝试另外一种方法:
* 下载[fastLink](https://github.com/OPTI-SURVEIL/fastLink),点击页面右边中间的绿色按钮Clone or Download，然后选择Download ZIP，记住存储位置，例如C:\Users\Qu\Downloads
* 下载[chinsimi](https://github.com/OPTI-SURVEIL/chinsimi),点击页面右边中间的绿色按钮Clone or Download，然后选择Download ZIP，记住存储位置，例如C:\Users\Downloads
* 打开R studio,在操作台中键入devtools::install_local(path = "C:\\Users\\Downloads\\fastLink-master.zip")来安装fastLink包
* 打开R studio,在操作台中键入devtools::install_local(path = "C:\\Users\\Downloads\\chinsimi-master.zip")来安装fastLink包

<a name="prep"></a>
## 3. 准备工作
### 3.1. 下载数据 
下载[此文件夹](https://github.com/OPTI-SURVEIL/RLManual)中以下文件：
* Name match 1.csv, Name match 2.csv - 样例数据（双击下载的文件可以用excel查看文件内容）
* linkage_utils.R - 匹配过程中需要的函数
* filled F-curves.Rdata - 设定姓名匹配相似度阈值所需要的数据
* final_xgb_model_10.Rdata - 机器学习模型数据


### 3.2. 将系统环境设置为中文
打开Rstudio，点击左上角加号新建Rscript。在新建的文件中输入以下代码，当选中代码时，点击右上角run可以运行选中的代码。因为我们需要匹配的记录是中文，因此我们需要首先将R环境设置成中文。在Windows系统上，可使用：
```
Sys.setlocale(category = 'LC_ALL', locale = 'Chinese')
```


### 3.3. 设置工作文件夹 
设置工作文件夹为保存步骤1中下载数据的文件夹，注意文件路径中应该用"/"而非"\"，例如不应该用"C:\Users\Documents\"而应该用"C:/Users/Documents/"。 例如：
```
setwd("C:/Users/Documents/")
```

```diff
- 请将C:/Users/Documents/替换为第1步中保存下载数据的路径
- 最好使用英文路径,即路径中最好不要有汉字
```

### 3.4. 加载所需要的R包
```
library(tidyverse)
library(fastLink)
library(ChinSimi)
library(xgboost)
library(readr)
```


### 3.5. 导入函数
导入包括所需要的函数的R文件linkage_utils.R（在步骤1中已经下载）
```
source('linkage_utils.R')
```

### 3.6. 导入机器学习模型相关文件
导入姓名匹配机器学习模型以及阈值设置数据
```
load('final_xgb_model_10.Rdata')
load('filled F-curves.Rdata')
```



<a name="usage"></a>
## 4. 使用方法
### 4.1. 导入数据

fastLink包采用Fellegi-Sunter记录匹配法，方法详细描述见[此文章](https://imai.fas.harvard.edu/research/files/linkage.pdf)。包中主要使用函数为fastLink()和getMatches()。fastLink()用于进行匹配，getMatches()用于提取相匹配的记录。
首先读取数据，以下为读取示例数据，其中S1为需要匹配的数据1，S2为需要匹配的数据2，以下为使用之前下载的示例数据。正确的匹配结果为S1中的1-100行分别与S2中的1-100行一一对应。
```
S1 <- read_csv("Name match 1.csv", locale = locale(encoding = "UTF-8"))
S2 <- read_csv("Name match 2.csv", locale = locale(encoding = "UTF-8"))
```
```diff
- 这里Name match 1.csv和Name match 2.csv为提供的示例数据，在实际应用中，请将数据保存在和之前下载的数据相同的文件夹，
- 并将Name match 1.csv和Name match 2.csv替换为您所需要匹配的文件名。
```
通过下列命令，可以查看S1和S2都包含哪些数据
```
View(S1)
View(S2)
```
以下为S1的前6行：
```
  name         sex   yob   mob   dob
  <chr>      <int> <int> <int> <int>
1 孙文           0  1975     6     1
2 庄子           1  1980    10    17
3 伊姆荷太普     1  1993     4     6
4 神a农氏        1  1983    11     9
5 陈水扁         0  1977     9     6
6 拿破仑         1  1958     8    19
```
以下为S2的前6行:
```
  name         sex   yob   mob   dob
  <chr>      <int> <int> <int> <int>
1 孙宗山         0  1975     6     1
2 庄子           1  1980    10    17
3 印何           1  1993     4     6
4 神农           1  1983    11     9
5 陈水扁         0  1977     9     6
6 拿破仑一世     1  1958     8    19
```
其中name字段为姓名, sex字段为性别（随机生成，不代表真实性别），yob为出生年份，mob为出生月份，dob为出生日期（随机生成，不代表真实出生日期）。NA表示该字段数据缺失。如果出现乱码，请尝试：
```
S1 <- read_csv("Name match 1.csv", locale = locale(encoding = "GB2312"))
S2 <- read_csv("Name match 2.csv", locale = locale(encoding = "GB2312"))
```

### 4.2. 数据清洗
```diff
- 这一部分也可以在excel中进行
```

姓名字段中，有时候会包括一些非汉字的字符，例如数字、字母和标点符号等（例如S1的第4行-神a农氏），因此需要首先进行数据清洗。在这里我们仅以Name match 1.csv作为示范，对S2的操作可以用同样方式进行。除了姓名外，其他字段也可以用类似的方法进行清洗。

**1. 删除字母**

首先提取包括字母的姓名的编号
```
alphainds <- grep('[a-z]', S1$name, ignore.case = TRUE) 
#本函数判断S1数据集的name字段中是否有字母a-z，当ignore.case被设置为TRUE时，可以同时考虑大写和小写字母。
本函数的返回参数为一个数组，代表包括字母的姓名的编号。
```
在操作台里输入alphainds，键入回车，可以看到以下结果，表示的是包含字母的姓名编号，可以看到第一个是4，即第四个姓名神a农氏
```
[1]  4 27 44 49 66 92
```
如果想要查看这些姓名都是什么，可以输入
```
S1$name[alphainds]
```
输出结果为
```
[1] "神a农氏"     "宣统d"       "毛泽东A"     "王b国维"     "五虎上将B"   "小泉纯e一郎"
```
如果想要将这些字母删除，可以使用如下代码
```
S1$name[alphainds] <- gsub('[a-z]','',S1$name[alphainds], ignore.case = T) 
#本函数第一个输入数据为需要替换的内容，这里表示字母；第二个输入数据表示替换为什么，这里是空，即表示删除要替换的内容；
第三个输入参数为需要替换的数据集或字段；第四个表示替换所有的大写和小写字母
```
检查是否替换成功
```
S1$name[alphainds]
```
输出结果
```
[1] "神农氏"     "宣统"       "毛泽东"     "王国维"     "五虎上将"   "小泉纯一郎"
```

**2. 删除数字**

删除数字的步骤和删除字母基本类似，唯一不同的是将a-z替换为1-9，并且不需要考虑大小写。
同样地，首先提取包含数字的姓名的行号。
```
numberinds <- grep('[1-9]', S1$name) 
#本函数判断S1数据集的name字段中是否有数字1-9。本函数的返回参数为一个数组，代表包括数字的姓名的编号。
```
在操作台里输入numberinds，键入回车，可以看到以下结果，表示的是包含数字的姓名的行号。
```
[1] 15 35 50 52 64 87
```
如果想要查看这些姓名都是什么，可以输入
```
S1$name[numberinds]
```
输出结果为
```
[1] "重耳2"     "帝舜6"     "卢8泰愚"   "马英9"     "汉5高祖"   "尉迟8敬德"
```
如果想要将这些数字删除，可以使用如下代码
```
S1$name[numberinds] <- gsub('[1-9]','',S1$name[numberinds]) 
#本函数第一个输入数据为需要替换的内容，这里表示所有数字；第二个输入数据表示替换为什么，这里是空，即表示删除要替换的内容；
第三个输入参数为需要替换的数据集或字段
```
检查是否替换成功
```
S1$name[numberinds]
```
输出结果
```
[1] "重耳"     "帝舜"     "卢泰愚"   "马英"     "汉高祖"   "尉迟敬德"
```

**3. 删除标点符号**

有时候，姓名中包括标点符号，比较常见的例如输入额外的没有意义的标点，例如“，”，“.”等。另外一些时候，这些标点符号可以表示特定的含义，例如“程?金”，这里“?”可能表示由于字迹过于潦草，输入者不确定这是什么字，也有可能是因为姓名中包含罕见字，常用字体库中没有该字，因此无法显示。另外一种常见的情况是包括括号（），并在括号中解释关于该记录的信息，例如释迦牟尼（法名）。我们可以删除没有意义的标点，但是保留有意义的标点。
首先可以提取有标点的姓名，并查看姓名:
```
punctinds <- grep('[[:punct:]]', S1$name) 
#本函数判断S1数据集的name字段中是否有标点符号。本函数的返回参数为一个数组，代表包括标点符号的姓名的编号。
```
在操作台里输入punctinds，键入回车，可以看到以下结果，表示的是包含数字的姓名的行号。
```
[1] 12 58 61 69 80 91 94 98
```
如果想要查看这些姓名都是什么，可以输入
```
S1$name[punctinds]
```
输出结果为
```
[1] "孔丘(又名孔子)" "手冢?治虫"      "张学.良"        "周(恩)来"       "长春(真)人"    
[6] "铃,木善幸"      "胡?涛"          "李:鸿章"    
```
这里的无意义标点符号包括“.”，“,”和“:”，所以我们分别将这些标点，以及多余的空格删除
```
S1$name[punctinds] <- gsub('\\.','',S1$name[punctinds]) #需要加上\\
S1$name[punctinds] <- gsub(',','',S1$name[punctinds])
S1$name[punctinds] <- gsub(':','',S1$name[punctinds])
S1$name[punctinds] <- gsub('[[:space:]]','',S1$name[punctinds])
#本函数第一个输入数据为需要替换的内容，这里表示相应的标点符号；第二个输入数据表示替换为什么，这里是空，即表示删除要替换的内容；
第三个输入参数为需要替换的数据集或字段
```
检查是否替换成功
```
S1$name[punctinds]
```
输出结果
```
[1] "孔丘(又名孔子)" "手冢?治虫"      "张学良"         "周(恩)来"       "长春(真)人"    
[6] "铃木善幸"       "胡?涛"          "李鸿章"   
```

### 4.3. 记录匹配

记录匹配使用fastLink()函数，在R操作台中，输入?fastLink可以查看函数的使用说明
```
valres <- fastLink(dfA = S1, dfB = S2, varnames = c('name','sex','yob','mob','dob'),
                   stringdist.match = 'name', stringdist.method = chin_strsim,
                   stringdist.args = list(model = model_10, reftable = unique(S1$name, S2$name)),
                   string.transform = transparser, 
                   string.transform.args = list(model = model_10,reftable = unique(S1$name, S2$name)),
                   cut.a = xgb10F1_filled$opt.thresh, verbose = T,estimate.only = F,cond.indep = F)
```
* dfA表示第一个需要匹配的记录集，dfB表示第二个需要匹配的记录集，这里因为我们在读入数据时，给数据集的命名为S1和S2，因此输入时，设置dfA = S1, dfB = S2。在实际操作中，需要根据你在读入数据时使用的数据集名称来设置。需要注意的是，在S1和S2中，请使用一致的字段名，并且最好使用英文字段名。例如，如果姓名字段在S1中的名称为xingming，那么在S2中也应该保持一致，而不能使用name。当对同一个数据集进行记录匹配或找出重复记录时，可将dfA和dfB设置为同一个数据集。

* varnames代表需要用来进行匹配的字段。在S1和S2中，我们用所有的5个字段，即name, sex, yob, mob和dob来进行匹配。stringdist.match表示需要利用我们的中文匹配方法来进行匹配的字段，即通过拼音，四角号码，五笔，偏旁部首，字型结构以及它们的组合来进行匹配，在这里我们仅对name字段进行中文字符串匹配。在实际操作中，请设置成你所需要进行姓名匹配的字段名称。如果不设置stringdist.match参数，那么将会对所有字段进行精确匹配。

* stringdist.method表示计算姓名相似性的函数，该函数的返回值为代表S1和S2中每个元素的相似性的矩阵。这里使用的是chin_strsim函数。**请不要修改此参数。**

* stringdist.args表示输入chin_strsim函数的参数，请将reftable = unique(S1$name, S2$name)中的S1, S2分别替换为你所使用的dfA和dfB的名字，name替换为你所使用的进行姓名匹配的字段名称。这里也可以使用用户自定义的函数，该函数需要包括使用哪些转换（拼音、四角号码、五笔等）以及如何计算这些转换之间的相似度，以及如何组合多种相似度。此外，由于我们使用的方法中考虑了各个姓和名出现的频次（例如常见姓的匹配比罕见姓的匹配蕴含的信息更少），因此需要提供一个列表用于计算姓和名的频次，即这里的reftable。

* string.transform表示用来生成拼音，四角号码，五笔，偏旁部首，字型结构以及它们的组合的函数。这里使用的是transparser函数。**除非你完全了解此函数的含义，否则请不要修改此参数。**

* string.transform.args表示输入给transparser函数的参数，同上请将reftable = unique(S1$name, S2$name)中的S1, S2分别替换为你所使用的dfA和dfB的名字，name替换为你所使用的进行姓名匹配的字段名称。

* cut.a表示在判断姓名是否匹配的时候的相似性的阈值，这里通过机器学习方法xgboost得到。我们的方法通过验证数据集来得到最适合的姓名匹配相似度阈值。在不同的记录匹配应用中，可以调整本阈值。调整方法见4.5节。

* verbose表示是否显示匹配过程中的详细信息，设为T（或者TRUE）时表示是，设为F（或者FALSE）时表示否。建议设为T。

* estimate.only表示是否只输出参数，不输出匹配结果，设为T时表示是，即仅输出模型的参数，建议设为F，则可同时输出参数和匹配结果。

* cond.indep表示是否假设每个字段相互独立（例如姓名匹配与否与姓名匹配与否无关），建议设为F


在匹配过程中，会输出以下信息。

```
==================== 
fastLink(): Fast Probabilistic Record Linkage
==================== 

If you set return.all to FALSE, you will not be able to calculate a confusion table as a summary statistic.
Calculating matches for each variable.
    Matching variable name using string-distance matching.

Attaching package: ‘Matrix’

The following object is masked from ‘package:tidyr’:

    expand


    Matching variable sex using exact matching.
    Matching variable yob using exact matching.
    Matching variable mob using exact matching.
    Matching variable dob using exact matching.
Calculating matches for each variable took 0.57 minutes.

Getting counts for parameter estimation.
    Parallelizing calculation using OpenMP. 1 threads out of 4 are used.
Getting counts for parameter estimation took 0.01 minutes.

Running the EM algorithm.
Running the EM algorithm took 0.09 seconds.

Selected match probability threshold is:  0.8833726653181944 
Getting the indices of estimated matches.
    Parallelizing calculation using OpenMP. 1 threads out of 4 are used.
Getting the indices of estimated matches took 0 minutes.

Deduping the estimated matches.
Deduping the estimated matches took 0 minutes.

Getting the match patterns for each estimated match.
Getting the match patterns for each estimated match took 0 minutes.

```

### 4.4. 提取匹配记录

提取匹配记录需要使用getMatches函数，这里的匹配概率阈值将会根据设置为valres$EM$threshold.match，即上一步输出的最优阈值。在实际操作中，用户也可以设为任何0-1间的数字。

```
matched_dfs <- getMatches(dfA = S1, dfB = S2, fl.out = valres, threshold.match = valres$EM$threshold.match, combine.dfs = FALSE, twolineformat = TRUE)
```
* dfA和dfB分别代表需要进行匹配的两个记录表。在进行去重或者自己和自己匹配时，也可以设置为同一个记录表
* fl.out代表fastLink的输出，这里即valres
* threshold.match代表用来定义记录对是否匹配的概率阈值，这里即上一步的输出valres$EM$threshold.match
* combine.dfs设置为F或者是FALSE时，输出两个数据表，设置为T或者是TRUE时，输出匹配记录合并在一起的数据表。当dfA为暴露和dfB为疾病数据时，输出合并的数据表更方便进一步的分析。
* twolineformat为输出数据的格式，设置为F时，输出两个数据表，设置为T时，将匹配的记录显示在一起。仅当combine.dfs被设置为F时，此参数才有意义。此输出格式适用于检查匹配结果是否合理。

以下分别为将combine.dfs, twolineformat设为T或者F时的示例结果

* combine.dfs = T, twolineformat = F, 结果为两个记录集显示在一起，仅显示数据集A中的各个属性。gamma.name, gamma.sex...分别代表每个每个属性是否匹配，0代表不匹配，2代表匹配。在第一行中，gamma.name = 0，即说明在第一个匹配的记录中，姓名不一致。
```
        name sex  yob mob dob gamma.name gamma.sex gamma.yob gamma.mob gamma.dob          posterior
1       孙文   0 1975   6   1          0         2         2         2         2 0.9999891240180887
2       庄子   1 1980  10  17          2         2         2         2         2 0.9999999664151652
3 伊姆荷太普   1 1993   4   6          0         2         2         2         2 0.9999891240180887
4     神农氏   1 1983  11   9          0         2         2         2         2 0.9999891240180887
5     陈水扁   0 1977   9   6          2         2         2         2         2 0.9999999664151652
6     拿破仑   1 1958   8  19          0         2         2         2         2 0.9999891240180887
```
* combine.dfs = F, twolineformat = F 这时将匹配的记录显示为两个数据集，即dfA.match里头的第一行和dfB.match里头的第一行相对应。
```
$dfA.match
             name sex  yob mob dob gamma.name gamma.sex gamma.yob gamma.mob gamma.dob          posterior
1            孙文   0 1975   6   1          0         2         2         2         2 0.9999891240180887
2            庄子   1 1980  10  17          2         2         2         2         2 0.9999999664151652
3      伊姆荷太普   1 1993   4   6          0         2         2         2         2 0.9999891240180887
4          神农氏   1 1983  11   9          0         2         2         2         2 0.9999891240180887
5          陈水扁   0 1977   9   6          2         2         2         2         2 0.9999999664151652
6          拿破仑   1 1958   8  19          0         2         2         2         2 0.9999891240180887

$dfB.match
         name sex  yob mob dob gamma.name gamma.sex gamma.yob gamma.mob gamma.dob          posterior
1      孙宗山   0 1975   6   1          0         2         2         2         2 0.9999891240180887
2        庄子   1 1980  10  17          2         2         2         2         2 0.9999999664151652
3        印何   1 1993   4   6          0         2         2         2         2 0.9999891240180887
4        神农   1 1983  11   9          0         2         2         2         2 0.9999891240180887
5      陈水扁   0 1977   9   6          2         2         2         2         2 0.9999999664151652
6  拿破仑一世   1 1958   8  19          0         2         2         2         2 0.9999891240180887
```

* combine.dfs = F, twolineformat = T 此时将匹配的记录交织显示
```
            row.index       name sex  yob mob dob p_match
1               dfA.1       孙文   0 1975   6   1        
2               dfB.1     孙宗山   0 1975   6   1        
3  agreement pattern:          0   2    2   2   2       1
4                                                        
5               dfA.2       庄子   1 1980  10  17        
6               dfB.2       庄子   1 1980  10  17        
7  agreement pattern:          2   2    2   2   2       1
8                                                        
9               dfA.3 伊姆荷太普   1 1993   4   6        
10              dfB.3       印何   1 1993   4   6        
11 agreement pattern:          0   2    2   2   2       1
12                                                       
13              dfA.4     神农氏   1 1983  11   9        
14              dfB.4       神农   1 1983  11   9        
15 agreement pattern:          0   2    2   2   2       1
16                                                       
17              dfA.5     陈水扁   0 1977   9   6        
18              dfB.5     陈水扁   0 1977   9   6        
19 agreement pattern:          2   2    2   2   2       1
20                                                       
21              dfA.6     拿破仑   1 1958   8  19        
22              dfB.6 拿破仑一世   1 1958   8  19        
23 agreement pattern:          0   2    2   2   2       1
```

### 4.5. 调整姓名匹配算法的阈值 （进阶）
姓名相似度的最优阈值取决于匹配数据对数目和不匹配数据对数目之间的比值，以及匹配中用到的其它的字段的可靠程度。如果如果匹配和不匹配的记录对之间的比值相对较大，而且其它的字段也可以提供足够的信息时，我们就可以降低姓名匹配相似度的阈值。这样一来，匹配算法的灵敏性就会加大，但是同时也有可能会带来更多的假阳性记录对（不应该被匹配上的记录对被匹配上了）。

为了得到最适宜的姓名匹配阈值，可以首先进行精确匹配来估算匹配记录对和不匹配记录对的比例，以及各标识字段蕴含的信息量。
```
exact_match_res <- fastLink(dfA = S1, dfB = S2, 
            varnames = c('name','sex','yob','mob','dob'),
            verbose = T, estimate.only = F, cond.indep = F)
```
输出结果为：
```
==================== 
fastLink(): Fast Probabilistic Record Linkage
==================== 

If you set return.all to FALSE, you will not be able to calculate a confusion table as a summary statistic.
Calculating matches for each variable.
    Matching variable name using exact matching.
    Matching variable sex using exact matching.
    Matching variable yob using exact matching.
    Matching variable mob using exact matching.
    Matching variable dob using exact matching.
Calculating matches for each variable took 0.39 minutes.

Getting counts for parameter estimation.
    Parallelizing calculation using OpenMP. 1 threads out of 4 are used.
Getting counts for parameter estimation took 0 minutes.

Running the EM algorithm.
Running the EM algorithm took 0.06 seconds.

Selected match probability threshold is:  0.5636415747235356 
Getting the indices of estimated matches.
    Parallelizing calculation using OpenMP. 1 threads out of 4 are used.
Getting the indices of estimated matches took 0 minutes.

Deduping the estimated matches.
Deduping the estimated matches took 0 minutes.

Getting the match patterns for each estimated match.
Getting the match patterns for each estimated match took 0 minutes.
```

接下来可以用F_adjust_link函数来估算姓名匹配相似度的阈值:
```
adjusted_F <- F_adjust_link(Fcurve = xgb10F1_filled$curvedat, 
                            flinkres = exact_match_res$EM,
                            thresh.match = exact_match_res$EM$threshold.match,
                            namecol = 'name',
                            plot = T) 
```
* Fcurve为从模型验证数据得到的包含多个阈值下的F1得分的对象
* flinkres为fastLink输出的EM对象
* thresh.match表示fastLink中匹配概率阈值
* namecol为存储了姓名的字段名
* plot表示是否绘制原始（红色）和校准后（蓝色）的F曲线

然后可以将计算得到的最优的姓名相似度阈值adjusted_F$opt.thresh输入到fastLink函数:
```
valres <- fastLink(dfA = S1, dfB = S2, 
            varnames = c('name','sex','yob','mob','dob'),
            stringdist.match = 'name', 
            stringdist.method = chin_strsim,
            stringdist.args = list(model = model_10, reftable = unique(S1$name, S2$name)),
            string.transform = transparser, 
            string.transform.args = list(model = model_10,reftable = unique(S1$name, S2$name)),
            cut.a = adjusted_F$opt.thresh, 
            verbose = T, estimate.only = F, cond.indep = F)

```

同之前一样，依旧可以用getMatches来得到相匹配的数据
```
opt_match <- getMatches(S1, S2, valres, valres$EM$threshold.match, combine.dfs = F, twolineformat = T)
```

```
            row.index       name sex  yob mob dob p_match
1               dfA.1       孙文   0 1975   6   1        
2               dfB.1     孙宗山   0 1975   6   1        
3  agreement pattern:          0   2    2   2   2       1
4                                                        
5               dfA.2       庄子   1 1980  10  17        
6               dfB.2       庄子   1 1980  10  17        
7  agreement pattern:          2   2    2   2   2       1
8                                                        
9               dfA.3 伊姆荷太普   1 1993   4   6        
10              dfB.3       印何   1 1993   4   6        
11 agreement pattern:          0   2    2   2   2       1
12                                                       
13              dfA.4     神农氏   1 1983  11   9        
14              dfB.4       神农   1 1983  11   9        
15 agreement pattern:          2   2    2   2   2       1
16                                                       
17              dfA.5     陈水扁   0 1977   9   6        
18              dfB.5     陈水扁   0 1977   9   6        
19 agreement pattern:          2   2    2   2   2       1
20                                                       
21              dfA.6     拿破仑   1 1958   8  19        
22              dfB.6 拿破仑一世   1 1958   8  19        
23 agreement pattern:          2   2    2   2   2       1
```

### 4.6. 不同姓名匹配方法的精度以及计算时长
在我们开发本方法的过程中，从单一的转换及基于该转换的相似度，到多个相似度的线性组合，再到到复杂的机器学习算法xgboost，我们尝试了一系列的中文人名匹配的方法。总的来说，运算时间和姓名匹配的精度均随着模型复杂程度增加，因此用户可能对较小的数据集使用高精度的算法，但是对于大的数据集来说，可能有时候需要牺牲精度来缩短运算的时间。
下图表示不同方法的精度：
![image](https://github.com/OPTI-SURVEIL/RLManual/blob/master/images/1.png)
下面两个图表示不同方法的运算时间随数据集大小增大的速度：
![image](https://github.com/OPTI-SURVEIL/RLManual/blob/master/images/2.png)
![image](https://github.com/OPTI-SURVEIL/RLManual/blob/master/images/3.png)
