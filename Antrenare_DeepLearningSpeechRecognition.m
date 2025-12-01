speedupExample = false; 
rng default 

% =========================================================================
% 1. INCARCAREA SI PREGATIREA DATELOR
% =========================================================================
% ATENTIE: Asigura-te ca ai rulat augmentDataset("ComandaMea") o data inainte!
datasetFolder = "ComandaMea"; 
commands = categorical(["casa","masina","dreapta","stanga","da","nu"]); % Comenzile tale personalizate
background = categorical("background");
includeFraction = 0.2; 

fs = 16e3; 
segmentDuration = 1;
segmentSamples = round(segmentDuration*fs); 

% --- FUNCTIE DE FILTRARE ADĂUGATĂ PENTRU A ASIGURA DURATA DE 1s ---
function [isValid] = isValidDuration(file, segmentSamples)
    % Folosim audioinfo pentru a verifica lungimea exacta in esantioane
    fileInfo = audioinfo(file);
    isValid = fileInfo.TotalSamples == segmentSamples;
end

% --- SETUL DE ANTRENARE (TRAIN) ---
ads = audioDatastore(fullfile(datasetFolder,"train"), ...
    IncludeSubfolders=true, ...
    FileExtensions=".wav", ...
    LabelSource="foldernames");

% Etapa NOUA: Filtrare doar pentru fișiere de 1s (pentru a remedia eroarea de performanta)
validFilesIdx = arrayfun(@(f) isValidDuration(f{1}, segmentSamples), ads.Files);
ads = subset(ads, validFilesIdx);
if sum(validFilesIdx) < numel(validFilesIdx)
    disp(["Avertisment TRAIN: S-au eliminat " + (numel(validFilesIdx) - sum(validFilesIdx)) + " fișiere care nu aveau exact 1s."]);
end

isCommand = ismember(ads.Labels,commands);
isBackground = ismember(ads.Labels,background); 
isUnknown = ~(isCommand|isBackground);

idx = find(isUnknown);
idx = idx(randperm(numel(idx),round((1-includeFraction)*sum(isUnknown))));
isUnknown(idx) = false;

ads.Labels(isUnknown) = categorical("unknown");
adsTrain = subset(ads,isCommand|isUnknown|isBackground);
adsTrain.Labels = removecats(adsTrain.Labels);
TTrain = adsTrain.Labels;

disp("Date de antrenare incarcate. Numar total de fisiere: " + numel(TTrain));

% --- SETUL DE VALIDARE (VALIDATION) ---
ads = audioDatastore(fullfile(datasetFolder,"validation"), ...
    IncludeSubfolders=true, ...
    FileExtensions=".wav", ...
    LabelSource="foldernames");

% Etapa NOUA: Filtrare doar pentru fișiere de 1s
validFilesIdx = arrayfun(@(f) isValidDuration(f{1}, segmentSamples), ads.Files);
ads = subset(ads, validFilesIdx);
if sum(validFilesIdx) < numel(validFilesIdx)
    disp(["Avertisment VALIDATION: S-au eliminat " + (numel(validFilesIdx) - sum(validFilesIdx)) + " fișiere care nu aveau exact 1s."]);
end

isCommand = ismember(ads.Labels,commands);
isBackground = ismember(ads.Labels,background);
isUnknown = ~(isCommand|isBackground);

idx = find(isUnknown);
idx = idx(randperm(numel(idx),round((1-includeFraction)*sum(isUnknown))));
isUnknown(idx) = false;

ads.Labels(isUnknown) = categorical("unknown");
adsValidation = subset(ads,isCommand|isUnknown|isBackground);
adsValidation.Labels = removecats(adsValidation.Labels);
TValidation = adsValidation.Labels;

disp("Date de validare incarcate. Numar total de fisiere: " + numel(TValidation));

if speedupExample
    numUniqueLabels = numel(unique(adsTrain.Labels));
    adsTrain = splitEachLabel(adsTrain,round(numel(adsTrain.Files) / numUniqueLabels / 20));
    adsValidation = splitEachLabel(adsValidation,round(numel(adsValidation.Files) / numUniqueLabels / 20));
end

% =========================================================================
% 2. EXTRACTIA FEATURE-URILOR (SPECTROGRAME BARK)
% =========================================================================
frameDuration = 0.025;
hopDuration = 0.010;
FFTLength = 512;
numBands = 50;

frameSamples = round(frameDuration*fs);
hopSamples = round(hopDuration*fs);
overlapSamples = frameSamples - hopSamples;

useParallel = false; % Seteaza la true daca ai Parallel Computing Toolbox
if exist('canUseParallelPool','builtin') && canUseParallelPool 
    useParallel = true;
end

afe = audioFeatureExtractor( ...
    SampleRate=fs, ...
    FFTLength=FFTLength, ...
    Window=hann(frameSamples,"periodic"), ...
    OverlapLength=overlapSamples, ...
    barkSpectrum=true);
setExtractorParameters(afe,"barkSpectrum",NumBands=numBands,WindowNormalization=false);

% --- Transformari pentru antrenare ---
transform1Train = transform(adsTrain,@(x)[zeros(floor((segmentSamples-size(x,1))/2),1);x;zeros(ceil((segmentSamples-size(x,1))/2),1)]);
transform2Train = transform(transform1Train,@(x)extract(afe,x));
transform3Train = transform(transform2Train,@(x){log10(x+1e-6)});

XTrain = readall(transform3Train,UseParallel=useParallel);
XTrain = cat(4,XTrain{:});
[numHops,~,~,~] = size(XTrain); 

% --- Transformari pentru validare ---
transform1Validation = transform(adsValidation,@(x)[zeros(floor((segmentSamples-size(x,1))/2),1);x;zeros(ceil((segmentSamples-size(x,1))/2),1)]);
transform2Validation = transform(transform1Validation,@(x)extract(afe,x));
transform3Validation = transform(transform2Validation,@(x){log10(x+1e-6)});

XValidation = readall(transform3Validation,UseParallel=useParallel);
XValidation = cat(4,XValidation{:});

% =========================================================================
% 3. DEFINIREA ARHITECTURII CNN
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

% =========================================================================
% 4. OPTIUNILE SI ANTRENAREA
% =========================================================================
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
% 5. EVALUAREA SI REZULTATELE
% =========================================================================
scoresValidation = minibatchpredict(trainedNet,XValidation);
YValidation = scores2label(scoresValidation,classes,"auto");
validationError = mean(YValidation ~= TValidation);

scoresTrain = minibatchpredict(trainedNet,XTrain);
YTrain = scores2label(scoresTrain,classes,"auto");
trainError = mean(YTrain ~= TTrain);

disp(["Eroare Antrenare: " + trainError*100 + " %";"Eroare Validare: " + validationError*100 + " %"])

figure(Units="normalized",Position=[0.2,0.2,0.5,0.5]);
cm = confusionchart(TValidation,YValidation, ...
    Title="Matricea de Confuzie pentru Validare", ...
    ColumnSummary="column-normalized",RowSummary="row-normalized");
% LINIE CORECTATĂ: Folosește categoriile reale din datele de validare
sortClasses(cm, categories(TValidation)) 

% --- FUNCTIA DE SUPORT (Necesita rulare o singura data pentru a pregati datele) ---
function augmentDataset(datasetloc)
adsBkg = audioDatastore(fullfile(datasetloc,"background"));
fs = 16e3; 
segmentDuration = 1;
segmentSamples = round(segmentDuration*fs);
volumeRange = log10([1e-4,1]);
numBkgSegments = 4000; 
numBkgFiles = numel(adsBkg.Files);
numSegmentsPerFile = floor(numBkgSegments/numBkgFiles);
fpTrain = fullfile(datasetloc,"train","background");
fpValidation = fullfile(datasetloc,"validation","background");

if ~exist(fpTrain, 'dir') 
    disp("Se genereaza segmentele de background. Vă rugăm așteptați...");
    mkdir(fpTrain)
    mkdir(fpValidation)
    
    for backgroundFileIndex = 1:numel(adsBkg.Files)
        [bkgFile,fileInfo] = read(adsBkg);
        [~,fn] = fileparts(fileInfo.FileName);
        
        if size(bkgFile,1) < segmentSamples
            warning("Fisierul de background %s este prea scurt si va fi ignorat.", fn);
            continue;
        end
        segmentStart = randi(size(bkgFile,1)-segmentSamples,numSegmentsPerFile,1);
        gain = 10.^((volumeRange(2)-volumeRange(1))*rand(numSegmentsPerFile,1) + volumeRange(1));

        for segmentIdx = 1:numSegmentsPerFile
            bkgSegment = bkgFile(segmentStart(segmentIdx):segmentStart(segmentIdx)+segmentSamples-1);
            bkgSegment = bkgSegment*gain(segmentIdx);
            bkgSegment = max(min(bkgSegment,1),-1); 
            afn = fn + "_segment" + segmentIdx + ".wav";

            if rand > 0.85 
                dirToWriteTo = fpValidation;
            else 
                dirToWriteTo = fpTrain;
            end
            ffn = fullfile(dirToWriteTo,afn);
            audiowrite(ffn,bkgSegment,fs)
        end
    end
    disp("Generarea segmentelor de background a fost finalizată.");
else
    disp("Folderele background pentru train/validation exista deja. Se continua.");
end
end