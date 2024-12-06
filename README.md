# Background: 
The longer you work on iOS, the easier it is to have your own packaged tool classes and methods, but the easier it is to encounter Apple's 4.3 listing review. There is also cocoapods, which is easy to use. If you don't need it, don't integrate it. If you have integrated it, don't use dynamic libraries.
# Principle: 
Traverse the source code directory, get the class name, method name, attribute name, constant name, and count the number of occurrences. Get the file content and remove the comments to get the MD5 value. Compare these properties of the two projects, find the duplicates, and calculate the duplication ratio.
# Current function: 
Analyze a single project. Analyze two projects you have done.
Supports automatic layout and can be used on Mac.



# 背景：
iOS做得越久就越容易有自己封装好的工具类和方法，但越容易遇到苹果上架审核4.3。还有使用顺手的cocoapods，用不上别集成，集成了别用动态库。
# 原理：
对源码目录进行遍历，获取类名、方法名、属性名、常量名，统计出现的次数。获取文件内容去掉注释后获得MD5值。比较两个项目的这些属性，找重复的地方，并计算重复的比例。
# 现在功能：
对单个项目分析。对自己做过的两个项目进行分析。
支持自动化布局，可以在Mac上使用。
