%% --- SCRIPT FINAL STABIL (V14): CORECTAT PENTRU EROAREA DE DIMENSIUNI FINALE ---

% Configurarea Mediului
speedupExample = false; 
rng default 

% =========================================================================
% 1. INCARCAREA DATELOR CUSTOM 
% =========================================================================

datasetFolder = fullfile(pwd,"ComandaMea"); 

comenzi = categorical(["masina","casa","dreapta","stanga","da","nu"]);
background = categorical("background");
fs = 16e3; 
segmentDuration = 1; 
segmentSamples = fs; 

% --- 1A. INCARCAREA DATELOR DE COMANDA/UNKNOWN (TRAIN) ---
adsTrainCommands = audioDatastore(fullfile(datasetFolder,"train"), ...
    IncludeSubfolders=true, ...
    FileExtensions=".wav", ...
    LabelSource="foldernames");

% Etichetare si Filtrare (neschimbată)
isCommand = ismember(adsTrainCommands.Labels,comenzi);
isUnknown = ~isCommand; 
adsTrainCommands.Labels(isUnknown) = categorical("unknown");
TTrainCommands = removecats(adsTrainCommands.Labels); 

numTrain = numel(adsTrainCommands.Files);
validSamplesTrain = true(numTrain, 1);
for k = 1:numTrain
    [audioData, ~] = read(adsTrainCommands); 
    if size(audioData, 1) ~= segmentSamples 
         validSamplesTrain(k) = false;
    end
    reset(adsTrainCommands);
end
adsTrainCommands = subset(adsTrainCommands, validSamplesTrain);
TTrainCommands = adsTrainCommands.Labels; 
disp("Date de antrenare incarcate si validate. Numar comenzi/unknown valide: " + numel(TTrainCommands));


% --- 1B. INCARCAREA DATELOR DE ZGOMOT (BACKGROUND) ---
adsBkg = audioDatastore(fullfile(datasetFolder,"background"), ...
    FileExtensions=".wav"); 
adsBkg.Labels = repmat(background, numel(adsBkg.Files), 1);
adsBkg.Labels = removecats(adsBkg.Labels); 

[adsBkgTrain, adsBkgValidation] = splitEachLabel(adsBkg, 0.85);


% --- 1D. INCARCAREA SETULUI DE VALIDARE (VALIDATION) ---
adsValidationCommands = audioDatastore(fullfile(datasetFolder,"validation"), ...
    IncludeSubfolders=true, ...
    FileExtensions=".wav", ...
    LabelSource="foldernames");

% Etichetare si Filtrare (neschimbată)
isCommand = ismember(adsValidationCommands.Labels,comenzi);
isUnknown = ~isCommand; 
adsValidationCommands.Labels(isUnknown) = categorical("unknown");

numValidation = numel(adsValidationCommands.Files);
validSamplesValidation = true(numValidation, 1);
for k = 1:numValidation
    [audioData, ~] = read(adsValidationCommands);
    if size(audioData, 1) ~= segmentSamples
         validSamplesValidation(k) = false;
    end
    reset(adsValidationCommands);
end
adsValidationCommands = subset(adsValidationCommands, validSamplesValidation);
TValidationCommands = adsValidationCommands.Labels; 
disp("Date de validare incarcate si validate. Numar comenzi/unknown valide: " + numel(TValidationCommands));

% =========================================================================
% 2. PREGATIREA DATELOR PENTRU ANTRENARE (EXTRACTIA SPECTROGRAMELOR)
% =========================================================================

% Setam parametrii
frameDuration = 0.025; hopDuration = 0.010;
FFTLength = 512; numBands = 50;

frameSamples = round(frameDuration*fs);
hopSamples = round(hopDuration*fs);
overlapSamples = frameSamples - hopSamples;

% Obiectul Audio Feature Extractor
afe = audioFeatureExtractor( ...
    SampleRate=fs, ...
    FFTLength=FFTLength, ...
    Window=hann(frameSamples,"periodic"), ...
    OverlapLength=overlapSamples, ...
    barkSpectrum=true);
setExtractorParameters(afe,"barkSpectrum",NumBands=numBands,WindowNormalization=false);


% --- FUNCTIA DE SEGMENTARE SI PRELUCRARE A BACKGROUND-ULUI ---
function [segments, labels] = segmentBackground(x, fs, segmentDuration, backgroundLabel)
    segmentSamples = round(segmentDuration * fs);
    overlap = 0; 
    
    % Padding daca fisierul e prea scurt (desi a fost filtrat la train/validation)
    if size(x, 1) < segmentSamples
        x = [x; zeros(segmentSamples - size(x, 1), 1)];
    end
    
    % Calculăm segmentele de 1s
    numSegments = floor(size(x, 1) / segmentSamples);
    segments = cell(numSegments, 1);
    
    for i = 1:numSegments
        startIdx = (i - 1) * (segmentSamples - overlap) + 1;
        endIdx = startIdx + segmentSamples - 1;
        segments{i} = x(startIdx:endIdx);
    end
    
    labels = repmat(backgroundLabel, numSegments, 1);
end

% --- FUNCTIA PIPELINE DE PRELUCRARE PENTRU COMENZI (fără segmentare) ---
function [featuresCell] = processCommand(audioData, segmentSamples, afe)
    % Padding
    paddedAudio = [zeros(floor((segmentSamples-size(audioData,1))/2),1); 
                   audioData; 
                   zeros(ceil((segmentSamples-size(audioData,1))/2),1)];
    % Extractie Spectrograma
    features = extract(afe, paddedAudio);
    featuresCell = {log10(features + 1e-6)};
end


% --- 2A. EXTRAGE SPECTROGRAME TRAIN: COMENZI ---
audioTrainCommands = readall(adsTrainCommands);
XTrainCommands = cell(numel(audioTrainCommands), 1);
for i = 1:numel(audioTrainCommands)
    XTrainCommands(i) = processCommand(audioTrainCommands{i}, segmentSamples, afe);
end


% --- 2B. EXTRAGE SPECTROGRAME TRAIN: BACKGROUND (cu segmentare) ---
audioTrainBkg = readall(adsBkgTrain);
XTrainBkg = cell(0);
YTrainBkg = categorical([]);

for i = 1:numel(audioTrainBkg)
    % Segmentare fișier lung de background
    [segments, labels] = segmentBackground(audioTrainBkg{i}, fs, segmentDuration, background);
    
    % Prelucrare fiecare segment
    for j = 1:numel(segments)
        features = extract(afe, segments{j});
        XTrainBkg{end+1} = log10(features + 1e-6);
    end
    YTrainBkg = [YTrainBkg; labels]; 
end

% --- 2C. COMBINARE TRAIN FINAL ---
XTrain = cat(4, XTrainCommands{:}, XTrainBkg{:});
TTrain = [TTrainCommands; YTrainBkg]; 
[numHops,numBands,~,~] = size(XTrain); 
disp("Spectrograme TRAIN generate. Dimensiune finală: " + size(XTrain, 4));


% --- 2D. EXTRAGE SPECTROGRAME VALIDATION: COMENZI ---
audioValidationCommands = readall(adsValidationCommands);
XValidationCommands = cell(numel(audioValidationCommands), 1);
for i = 1:numel(audioValidationCommands)
    XValidationCommands(i) = processCommand(audioValidationCommands{i}, segmentSamples, afe);
end


% --- 2E. EXTRAGE SPECTROGRAME VALIDATION: BACKGROUND (cu segmentare) ---
audioValidationBkg = readall(adsBkgValidation);
XValidationBkg = cell(0);
YValidationBkg = categorical([]);

for i = 1:numel(audioValidationBkg)
    [segments, labels] = segmentBackground(audioValidationBkg{i}, fs, segmentDuration, background);
    for j = 1:numel(segments)
        features = extract(afe, segments{j});
        XValidationBkg{end+1} = log10(features + 1e-6);
    end
    YValidationBkg = [YValidationBkg; labels];
end

% --- 2F. COMBINARE VALIDATION FINAL ---
XValidation = cat(4, XValidationCommands{:}, XValidationBkg{:});
TValidation = [TValidationCommands; YValidationBkg];

disp("Spectrograme VALIDATION generate. Dimensiune finală: " + size(XValidation, 4));

% Verificare finală că numerele se potrivesc
if size(XTrain, 4) ~= numel(TTrain)
    error('Eroare internă de programare: Dimensiunile Predictors (XTrain) și Targets (TTrain) nu se potrivesc după prelucrare!');
end

% =========================================================================
% 3. DEFINIREA SI ANTRENAREA ARHITECTURII CNN
% (Neschimbată)
% =========================================================================

classes = categories(TTrain);
classWeights = 1./countcats(TTrain);
classWeights = classWeights'/mean(classWeights);
numClasses = numel(classes); 

timePoolSize = ceil(numHops/8);
dropoutProb = 0.2;
numF = 12;

layers = [
    imageInputLayer([numHops,afe.FeatureVectorLength])
    
    convolution2dLayer(3,numF,Padding="same"); batchNormalizationLayer; reluLayer;
    maxPooling2dLayer(3,Stride=2,Padding="same");
    
    convolution2dLayer(3,2*numF,Padding="same"); batchNormalizationLayer; reluLayer;
    maxPooling2dLayer(3,Stride=2,Padding="same");
    
    convolution2dLayer(3,4*numF,Padding="same"); batchNormalizationLayer; reluLayer;
    maxPooling2dLayer(3,Stride=2,Padding="same");
    
    convolution2dLayer(3,4*numF,Padding="same"); batchNormalizationLayer; reluLayer;
    convolution2dLayer(3,4*numF,Padding="same"); batchNormalizationLayer; reluLayer;
    
    maxPooling2dLayer([timePoolSize,1]) 
    dropoutLayer(dropoutProb)

    fullyConnectedLayer(numClasses)
    softmaxLayer];

miniBatchSize = 128;
validationFrequency = floor(numel(TTrain)/miniBatchSize);
options = trainingOptions("adam", ...
    InitialLearnRate=3e-4, ...
    MaxEpochs=15, ...
    MiniBatchSize=miniBatchSize, ...
    Shuffle="every-epoch", ...
    Plots="training-progress", ...
    Verbose=false, ...
    ValidationData={XValidation,TValidation}, ...
    ValidationFrequency=validationFrequency, ...
    Metrics="accuracy");

disp(">>> Începem Antrenarea. Vă rugăm așteptați... <<<");

trainedNet = trainnet(XTrain,TTrain,layers,@(Y,T)crossentropy(Y,T,classWeights(:),WeightsFormat="C"),options);

disp(">>> Antrenarea s-a finalizat! <<<");


% =========================================================================
% 4. EVALUAREA SI REZULTATELE
% =========================================================================

scores = minibatchpredict(trainedNet,XValidation);
YValidation = scores2label(scores,classes,"auto");
validationError = mean(YValidation ~= TValidation);

scores = minibatchpredict(trainedNet,XTrain);
YTrain = scores2label(scores,classes,"auto");
trainError = mean(YTrain ~= TTrain);

disp(["Eroare Antrenare: " + trainError*100 + " %";"Eroare Validare: " + validationError*100 + " %"])

figure(Units="normalized",Position=[0.2,0.2,0.5,0.5]);
cm = confusionchart(TValidation,YValidation, ...
    Title="Matricea de Confuzie pentru Validare", ...
    ColumnSummary="column-normalized",RowSummary="row-normalized");

sortClasses(cm, classes) 

disp("Modelul este antrenat! Poti acum sa salvezi 'trainedNet' sau sa-l testezi pe fișiere noi.");