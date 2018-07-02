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
