# keys/

minisign 公钥。`frey.pub` 由需求方在私有仓跑 `ops/scripts/release-keygen.sh`（Windows `release-keygen.bat`）时生成放进来：私钥与口令当场写进私有仓的 Secret，不落盘。同一把公钥编进 `frey` 二进制（`frey update` 核签名用）；换钥时新旧两把并存一版。

核一个下载的包：

```
minisign -Vm frey-<版本>-<平台>.tar.gz -p frey.pub
```
