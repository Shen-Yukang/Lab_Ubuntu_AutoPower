###
# 假设远程仓库地址为`git@github.com:Shen-Yukang/Lab_Ubuntu_AutoPower.git`(👈这个根据你实际要推送的仓库地址来修改)，默认分支为main，本地还未创建仓库！！！
# 本地空仓库绑定远程仓库
###

# 1. 初始化本地Git仓库
git init

# 2. 添加所有文件到暂存区
git add .

# 3. 创建初始提交
git commit -m "Initial commit: Ubuntu auto power management system"

# 4. 添加远程仓库（根据）
git remote add origin git@github.com:Shen-Yukang/Lab_Ubuntu_AutoPower.git

# 5. 推送到远程仓库
# 首次推送建议使用 -u 参数
# -u 参数的作用是设置**上游分支**（upstream branch），它会建立本地分支与远程分支的跟踪关系。
# **区别：**
# 1. `git push origin main` - 只是推送代码
# 2. `git push -u origin main` - 推送代码 + 设置跟踪关系
# **设置跟踪关系后的好处：**
# - 以后可以直接用 `git push` 和 `git pull`，不需要指定远程仓库和分支
# - `git status` 会显示本地分支与远程分支的同步状态
# - 可以使用 `git branch -vv` 查看跟踪关系
# **示例：**
# ```bash
# # 首次推送使用 -u
# git push -u origin main
# 
# # 之后就可以简化命令
# git push          # 等同于 git push origin main
# git pull          # 等同于 git pull origin main
# ```
git push -u origin main


#####
# 如果遇到默认分支问题，可能需要：
#####

# 如果远程仓库默认分支是master
git branch -M main
git push -u origin main

# 或者推送到master分支
git push -u origin master