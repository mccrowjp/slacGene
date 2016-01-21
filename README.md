# slacGene
### SVG Large Annotated Circular Gene map drawing program

A simple, extensible, Perl script for producing figures of circular gene maps.

* Originally written to produce a custom figure of SNP coverage and large deletions in a study of human mitochondrial DNA (Fig. 3, ![McCrow, Peterson, et. al, 2015](http://onlinelibrary.wiley.com/doi/10.1002/pros.23126/full))
* Because it is a single Perl script with no external dependencies, it is easy to run, and easy to further customize
* SVG is used because it is a scalable format allowing for very small representations of gene maps or highly magnified regions with unlimited resolution

Examples
--------

See [examples/](./examples) for a tutorial

*SNPs and large deletions in mtDNA*

![slacgene_mtdna_gene_snp_map](https://cloud.githubusercontent.com/assets/14023091/12496238/52a2d2ba-c049-11e5-8fbe-9ed4db652b0c.png)

Usage
-----

```
Usage: slacGene.pl (options)

options:
    -f            force overwrite of output file (default: no overwrite)
    -h            show help
    -i file       input file (use '-' for STDIN)
    -o file       output file (default: STDOUT)
```

Dependencies
------------

* Perl (https://www.perl.org/get.html)
