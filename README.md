# 记录匹配

* TOC {:toc}

## 背景
在信息录入过程中，因为从纸质文本到电子信息的转录错误（例如报告病例姓名过于潦草），以及在电子信息输入过程中的错误（例如王方和王芳），同一个人在大疫情中的记录的姓名，性别，出生年月及其他信息可能并不完全一致，这就会给后续的数据处理及数据分析过程带来困难。例如在分析乙肝报告病例过程中，由于目前乙肝并无法治愈，所以在计算发病率的过程中，应该排除以前报告过的病例，但是如果该次报告的病人姓名和之前的记录中并不完全一致时，使用精确匹配就无法准确的识别出之前报告过的记录。

现有的记录匹配算法多基于英文文本开发，对于中文来讲并不适用。对于中文人名来讲，首先名字大多只包括2-4个汉字，如果像英文人名一样，仅考虑字符之间的[编辑距离相似度](https://www.cnblogs.com/ivanyb/archive/2011/11/25/2263356.html)，会给结果带来很大的偏差。例如，从程咬金到程幺金，编辑距离为1，编辑距离相似度为0.66，而从Charles到Chales，编辑距离为1，编辑距离相似性为0.86。由于中国人的命名习惯，兄弟姐妹的名字常只有一个汉字的差异，例如蒋经国和蒋纬国，宋庆龄和宋美龄，因此仅靠编辑距离相似度来进行中文记录匹配远远不够。其次，中文是象形文字，从汉字本身并不能知道读音，因此英文中常见的基于读音匹配的算法，例如[Soundex](https://riddickbryant.iteye.com/blog/561665)也并不能直接应用于汉字。

基于汉字以及中文人名的特点，我们改进了现有的记录匹配R包fastLink，将我们开发的利用机器学习方法xgboost来进行姓名匹配的方法融入fastLink中，该姓名匹配方法可以同时考虑汉字的读音（拼音），字形（五笔和四角号码），偏旁部首及结构。除了姓名，在记录匹配中还可以同时考虑其他的属性，例如性别，出生年月，地址等。本文档将介绍fastLink包的安装方法，使用方法以及结果解读。

## 安装
1. [安装R及RStudio](https://blog.csdn.net/Joshua_HIT/article/details/73741139)。Rstudio的使用见[R语言初级教程](https://zhuanlan.zhihu.com/p/45503712)。
2. [安装Rtools](https://www.cnblogs.com/liugh/p/9937489.html)-只需要步骤一和二，即安装和设置环境变量
3. [安装所需要的R包](http://blog.sciencenet.cn/blog-2379401-936653.html)tidyverse, xgboost和devtools，可按照链接中的方法1来安装，即在RStudio的操作台中输入install.packages("tidyverse")，之后回车。另外两个包可以按照同样的方法安装。 
4. 使用以下代码安装Berkeley开发的包chinsimi, fastLink。
```
devtools::install_github('OPTI-SURVEIL/fastLink',dependencies = T, force = TRUE)
devtools::install_github('OPTI-SURVEIL/chinsimi',dependencies = T, force = TRUE)
```

## 准备工作
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


## 使用方法

