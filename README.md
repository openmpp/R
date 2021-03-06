# openMpp R package

This repository is a part of [OpenM++](http://www.openmpp.org/) open source microsimulation platform.
It contains openMpp R package which allow read and update openM++ model database.

As it is today openMpp package tested only with R up to version 3.6.3 and R version 4 has not been tested yet.

## Install and use latest release

Download [latest openMpp R package release](https://github.com/openmpp/r/releases/latest) and install:
```
install.packages("~/openMpp_N.N.N.tar.gz", repos = NULL, type = "source")
library(DBI)
library("openMpp")
library("RSQLite")
```

Download [latest openM++ release](https://github.com/openmpp/main/releases/latest), unpack it and `setwd()` to models directory:
```
setwd("~/openmpp_win_20210209/models/bin")
```

Try our examples:

- life_vs_mortality_test.R: [analyze DurationOfLife using MortalityHazard parameter](https://ompp.sourceforge.io/wiki/index.php/Run_Model_from_R)
- riskpaths_childlessness.R: [analyze contribution of delayed union formations versus decreased fertility on childlessness](https://ompp.sourceforge.io/wiki/index.php/Run_RiskPaths_Model_from_R)

## Build from sources and install

```
R CMD build openMpp

install.packages("RSQLite")
install.packages("~/openMpp_N.N.N.tar.gz", repos = NULL, type = "source")
```

As it is today only SQLite databases supported. 
For other vendors (Microsoft SQL, MySQL, PostgreSQL, IBM DB2, Oracle) only select from databse tested, update not implemented.

Please check openMpp package `man` documentation and `inst` examples.
Also visit our [wiki](https://ompp.sourceforge.io/wiki/) for more information.

License: MIT.

E-mail: _openmpp dot org at gmail dot com_
