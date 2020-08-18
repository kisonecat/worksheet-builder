# Worksheet Builder

Suppose you have a collection of `.tex` files many of which contain exercises of the form

```latex
\begin{exercise}\label{my-label}
Do this task.
\begin{solution}
Here is how I would have done it.
\end{solution}
\end{exercise}
```

This collection of `.tex` files is stored in a directory referred to
as the "root."

Then `ruby build-worksheet.rb` will compile a worksheet like

```latex
\documentclass{article}
\begin{document}
  \exercise{my-label}
\end{document}
```

and expand any `\exercise`s into the contents of the corresponding
`\begin{exercise}`.

## Getting Started

First, install a copy of the Worksheet Builder by running
```
git clone https://github.com/kisonecat/worksheet-builder
cd worksheet-builder
```

Create a file called `sample.tex` with content like the following
```latex
\documentclass{article}

\input{/path/to/your/preamble.tex}

% to number exercises
\newcounter{exer}
\newenvironment{exercise}{\par\refstepcounter{exer}\theexer.\quad}{}

% to include solutions but grayed out
\usepackage{xcolor}
\newenvironment{solution}{\color{gray}}{\color{black}}

\title{Worksheet 17}
\date{July 17, 2017}
\author{Math 1234}

\setlength{\parindent}{0in}
\setlength{\parskip}{1ex}

\begin{document}
\maketitle

\exercise{c5.2.3} % these are \ref's to your own exercises

\exercise{c5.3.2}

\exercise{c5.7.1a}

\end{document}
```
Finally suppose the `.tex` files with the `\label`ed `\begin{exercise}`s are all stored under a directory called `/path/to/my/tex/files`.  Running the command
```
ruby build-worksheet.rb --root=/path/to/my/tex/files --solutions sample.tex --output=output.tex
```
The expected result is a file called `output.tex` with the `\exercise`s replaced with the content inside the corresponding `exercise` environment.

## A Ready Example for Linear Algebra

For Golubitsky's Linear Algebra text, a example called `homework-sample.tex` is provided, along with scripts to make the process easy.  Open a terminal in the ``worksheet-builder`` directory.  Assuming that the source for the linear algebra text is in the relative directory ``../laode``, you may check your installation and compile the sample by running the command
```
./script_both.sh homework-sample.tex
``` 
Four notable files are produced:

`homework-samplee.tex` and `homework-samplee.pdf`, the source and pdf for the homework exercieses. 

`homework-samples.tex` and `homework-samples.pdf`, the source and pdf for the homework exercises with solutions. 

