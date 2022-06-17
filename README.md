# Using openM++ from R

This repository is a part of [OpenM++](http://www.openmpp.org/) open source microsimulation platform.
It contains two independent implementations of R tools for openM++ models:
* how-to use examples and small set of helper functions for integration between R and `oms` web-service
* openMpp R package which allow read and update openM++ model database on your local computer.


# How to use `oms` web-service from R to run models

OpenM++ web-service (oms) is a JSON web-service written in Go and used from openM++ UI JavaScript.
It is also possible to use it from any modern software (.NET, Python, Java, Perl, R, etc.) to run openM++ models,
prepare input data and retrive output results. 

In order to use it on your local desktop please do:
* download openM++ release from https://github.com/openmpp/main/releases/latest
* unpack it into any directory
* start `oms` web-service:
  * on Windows:
  ```
  cd C:\my-openmpp-release
  bin\ompp_ui.bat
  ```
  * on Linux or MacOS:
  ```
  cd ~/my-openmpp-release
  bin/oms
  ```

There are few examples and small set of helper functions in `oms-R` part of that repository.
Please consult our wiki for [oms API details.](https://github.com/openmpp/openmpp.github.io/wiki/Oms-web-service)


## Install and use openMpp R package

OpenMpp package tested only with R up to version 3.6.3, please use above `oms` web-service API if you need additiomal functionality.

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

Examples can be found at: [R / openMpp / inst/ ](https://github.com/openmpp/R/tree/master/openMpp/inst)

Above examples are also documented at our wiki:

- life_vs_mortality_test.R: [analyze DurationOfLife using MortalityHazard parameter](https://github.com/openmpp/openmpp.github.io/wiki/Run-Model-from-R)
- riskpaths_childlessness.R: [analyze contribution of delayed union formations versus decreased fertility on childlessness](https://github.com/openmpp/openmpp.github.io/wiki/Run-RiskPaths-Model-from-R)


## Build openMpp R package from sources

```
R CMD build openMpp

install.packages("RSQLite")
install.packages("~/openMpp_N.N.N.tar.gz", repos = NULL, type = "source")
```

As it is today only SQLite databases supported. 
For other vendors (Microsoft SQL, MySQL, PostgreSQL, IBM DB2, Oracle) only select from databse tested, update not implemented.

Please check openMpp package `man` documentation and `inst` examples.
Also visit our [wiki](https://github.com/openmpp/openmpp.github.io/wiki) for more information.

## Screenshots

**NewCaseBased** model:  loop over MortalityHazard parameter to analyze DurationOfLife output value.

![Example of NewCaseBased model run.](/images/RStudio_NewCaseBased_oms_2022-06-16.png "Example of NewCaseBased model run.")

**RiskPaths** model: analyze contribution of delayed union formations versus decreased fertility on childlessness.

![Example of RiskPaths model run.](/images/RStudio_RiskPaths_oms_2022-06-16.png "Example of RiskPaths model run.")

License: MIT.

E-mail: _openmpp dot org at gmail dot com_
