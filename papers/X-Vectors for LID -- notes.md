# X-Vectors for LID -- notes

## 2. X-vector System

### 2.1 Overview
- Originally for speaker recognition -- apparently, the idea generalises well
- Fixed-length embeddings from variable-length speech segments
- Code open-sourced as a Kaldi recipe

### 2.2 Architecture
- Feedworward DNN: TDNN (1D CNN) with 3 convolutional layers.
	- Translational invariance.
- Scans input sequence with a 15-frame window, producing sequence of longer-range feature vectors
- Statistics pooling layer computes first 2 moments of the features over entire speech segment
- Bottleneck layers reduce dimensionality before softmax layer does final classification
- After training, embeddings -- X-vectors -- taken from the bottleneck layers (from before the ReLU nonlinearity)

### 2.3 Training
- Training data: very short speech segments (2-4s)
- SGD, objective function cross-entropy (standard for multiclass classification together with softmax)
- Data augmentation with realistic additions: noises, reverberation, music, slight speed changes.
	- Amount of training data increased 6x, also embeddings more robust to real-life speech environment effects

### 2.5 Features
- Only speech frames (SAD)
- 3 types of features tested: 
	- MFCCs
	- Bottleneck features -- 60-D embeddings extracted from a TDNN trained on MFCCs for ASR (to classify triphones)
	- BNFs either monolingual (trained just on Fisher English corpus), or multilingual (on 23 languages from IARPA Babel)
- Mean-normalised over 3s sliding window => not focusing on phoneme-level short-term features


## 4. Classifier
- Direct classification can be done as well as extracting embeddings and using existing i-vector classifiers
- Gaussian classifier trained on longer segments (3-60s) augmented with noise, music, reverberation, speed changes, babble noise and a narrowband transform
- Embeddings are normalised and dimensionality reduced before being classified

## 5. Corpora
- NIST LRE 2017 -- telephone speech and wideband speech from videos -- both downsampled to 8kHz
- 14 languages from 5 language families, aim: differentiate between closely related languages (GB/US English)
- MUSAN and room impulse response (RIR) -- opensourced datasets