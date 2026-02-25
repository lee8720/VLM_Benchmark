This repository contains the evaluation resources for the study:

**Evolution of Diagnostic Performance in Vision–Language Models:  
A 13-Model Evaluation Against Human Readers in Thoracic Imaging**

---

## Repository Contents

### 📊 Benchmark Case Set
**Thoracic_VLM_Benchmark_Case_Set.xlsx**

- 100 curated thoracic imaging cases
- Clinical metadata
- Multiple-choice answer options with answer keys
- Radiologist-authored imaging descriptions used in the description-input condition

---

### 🤖 Model Inference Logs
**Thoracic_VLM_Benchmark_Model_Outputs_With_Rationales.xlsx**

- Full inference outputs for all 13 models
- Three repeated zero-shot runs per case
- Top-1 predictions and probability scores
- Model-generated rationales
- Top-1 and Top-3 correctness indicators

---

### 📝 Prompts
- `image_input_prompt.txt`
- `description_input_prompt.txt`

Standardized zero-shot prompts used for model evaluation.

---

### 📈 Evaluation Code
**compute_accuracy_agreement_kappa_bootstrap.R**

Reproduces:

- Top-1 accuracy
- Top-3 hit rate
- Fleiss’ κ intertrial agreement
- 3/3 agreement proportions
- Bootstrap confidence intervals

All performance metrics reported in the manuscript can be reproduced from the released inference logs using this script.

---

## Dataset

The image set used in this study can be downloaded from the following link:

[Download Image Set (Dropbox)](https://www.dropbox.com/scl/fo/4hc3g3ajvg293e47cvegq/AE0qN_UBjHEKveH_MlsUgqg?rlkey=uy5mzrn1a1cipogadmyfbzpyo&st=wgrmo5yq&dl=0)
