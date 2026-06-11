# lloomr: Concept Induction from Text with Large Language Models

An R implementation of the LLooM concept induction algorithm (Lam et
al., 2024,
[doi:10.1145/3613904.3642830](https://doi.org/10.1145/3613904.3642830) )
for extracting and applying interpretable, high-level concepts from text
data using large language models. The pipeline distills documents into
salient excerpts and bullet-point summaries, clusters them via text
embeddings, asks an LLM to synthesize named concepts with inclusion
criteria, reviews and deduplicates the concept set, and then scores
every document against every concept. Translated from the Python package
'text_lloom'.

## See also

Useful links:

- <https://github.com/zilinskyjan/lloomr>

- <https://zilinskyjan.github.io/lloomr/>

- Report bugs at <https://github.com/zilinskyjan/lloomr/issues>

## Author

**Maintainer**: Jan Zilinsky <zilinsky09@gmail.com> \[copyright holder\]

Other contributors:

- Michelle Lam (Copyright holder of the original Python implementation
  (text_lloom), from which this package is translated) \[copyright
  holder\]
