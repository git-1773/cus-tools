### 1️⃣ 构建镜像（一次）
```shell
docker build -t clip-feature:v0 .
```

### 2️⃣ 运行并挂载数据目录（关键）
```shell
docker run --rm \
  -v $(pwd):/app \
  clip-feature:v0 \
  python batch_extract.py
```

解释：
* --rm：跑完即删
* -v $(pwd):/app：
  * clips / csv 都在宿主
  * 容器只当计算器
* python batch_extract.py：入口

### 3️⃣ 结果在哪里？
```shell
project/dataset_v0.csv
```

```shell
docker run --rm \
  -v $(pwd):/app \
  clip-feature:v0 \
  python train_v0.py

```