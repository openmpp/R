# openMpp R package

This repository is a part of [OpenM++](http://www.openmpp.org/) open source microsimulation platform.
It contains openMpp R package which allow read and update openM++ model database.

## Build and install

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
