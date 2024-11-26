# 115-strm
通过115网盘生成下载目录树，自动生成strm文件，使用alist的情况下，可添加到emby进行播放，并且支持将目录树导入到alist的索引数据库，目前只测试音乐，其他多媒体格式应也是可以的<br><br>
由于115目录树没有定义文件和文件夹，脚本采用常见的文件格式来区分，如果你处理的格式比较特别，可在高级配置里面查看内置的文件格式和新增文件格式
# 分享音乐
https://115.com/s/swhsphs33xj?password=0000#
音乐22万首14.39T音乐包1
访问码：0000

https://115.com/s/swhsphb33xj?password=0000#
音乐22万首14.39T音乐包2
访问码：0000

https://115.com/s/swhspho33xj?password=0000#
音乐22万首14.39T音乐包3
访问码：0000


# 测试环境
系统ubuntu20
安装好python
执行需要sudo权限

# 生成文件的目录树
最好是将要处理的文件放在一个目录，生成教程<br><br>
https://115.com/115115/T496626.html<br><br>

下载后将目录树放到ubuntu的目录
# strm生成部分
最好在存放目录树的地方执行脚本
```bash
sudo bash -c "$(curl -fsSL https://raw.githubusercontent.com/suixing8/115-strm/main/115-strm.sh)"
```
# 使用教程

1: 将目录树转换为目录文件<br><br>
2: 生成 .strm 文件<br><br>
3: 建立alist索引数据库<br><br>
4: 高级配置（处理非常见媒体文件时使用）<br><br>


![image](https://github.com/user-attachments/assets/d2f203ae-ba6d-4bec-a339-f142d2b28b86)
<br><br>
## 1: 将目录树转换为目录文件
1是必操作项，2或者3，根据自己的需求使用<br><br>
![image](https://github.com/user-attachments/assets/caf4a831-36ae-4660-a754-31110ffa95e2)

## 2: 生成 .strm 文件
输入 .strm 文件保存的路径<br><br>
![image](https://github.com/user-attachments/assets/e3a53987-e1db-45c3-930a-5c9f54847972)

输入剔除选项（输入要剔除的目录层级数量）：<br><br>
看以下的解释后输入<br><br>
这个的目的就是为了生成的strm结构能和alist的结构一致，我贴出我的示例<br><br>
我在alist挂载的是music这个目录，alist挂载是不显示music这个目录，直接显示music目录下的文件<br><br>
![image](https://github.com/user-attachments/assets/53fb66f0-93fb-4948-afe7-00c2554b4373)<br><br>

比如我的115目录是/alist/music/A.歌手歌单，要处理的是/music这个文件夹<br><br>

![image](https://github.com/user-attachments/assets/eefc6cd6-e6b1-49b3-b89e-30e14f042e59)<br><br>

115目录树在生成的时候，会多自动多生成建立目录树文件的上一级目录
也就是我生成music这个文件夹的目录树的时候，目录树会生成/alist/music
所以115自动生成的目录树对于alist来说，多了2层目录，所以这种情况下，目录层级数量输入2，看不懂就多实践<br><br>
![image](https://github.com/user-attachments/assets/c89ea3f3-aa39-4939-b272-4c8eb34f0e5b)<br><br>

输入alist的ip地址+端口，等待处理后，strm文件创建到此结束


## 3: 建立alist索引数据库

alsit版本不能太低，最好在v3.7以后的版本,

将alsit停止后，备份data.db数据库，将data.db数据库文件存放到脚本执行的目录

在主页面选择3
脚本会自动获取当前的文件提供选择,剔除路径和strm同理<br><br>
![image](https://github.com/user-attachments/assets/d056c3ae-7d56-4c63-bfe5-1cc07dde6520)
<br><br>

根据实际情况选择替换还是新增到数据路的索引表，这个只会修改数据库的索引表，不会进行其他操作<br><br>

![image](https://github.com/user-attachments/assets/36d1aeeb-6af8-4f20-bf0b-bb2701884ca1)
<br><br>

将data.db上传到alist目录，替换data.db，再次提醒data.db提前备份<br><br>

![image](https://github.com/user-attachments/assets/47a876cb-9686-406a-a0fc-848488be1de7)<br><br>


开启alist，以下为效果，理论上，你可以将整个115网盘都挂载到alist，并且在alist上就可以搜索和观看<br><br>

![image](https://github.com/user-attachments/assets/a38c96e5-f4fb-4790-9da9-b422bab1d5ee)<br><br>


如果你是苹果手机，推荐使用Fileball，使用alist添加后，不能是webdav的方式添加，添加后，选择搜索，全局搜索，可以直接调用alist的api进行搜索
这个比较适合看电影电视剧综艺，因为Fileball不支持音乐，这个是目前我所使用的众多app中，唯一一个支持调用alist搜索api的<br><br>

![4261a8529bb4f3a4083fb4e54eddbd1](https://github.com/user-attachments/assets/9d4f8d0e-51aa-40ae-9f2a-94200ac96aa9)<br><br>


# 最后，转发请注明出处
感谢ChatGPT-4o提供的代码<br><br>
联系https://t.me/gengpengw




