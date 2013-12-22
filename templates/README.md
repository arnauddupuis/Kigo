In this document is described the notion of template.

What is it :
------------

It is a directory that contains many files (list and function below). Files in a template directory are text files with a .cgtpl extension. It basically a text file filled with code and variables that will be process at generation time.
There is one special file though: the template.ini file (see below).
Each file describe either something global (a class, a program, etc.) or something specific (a setter, a getter, etc.). It can go to the uber specific if needed.


Files :
-------

template.ini : a key=value text file that controls the basic configuration of the template. See a template.ini for the description of each options.