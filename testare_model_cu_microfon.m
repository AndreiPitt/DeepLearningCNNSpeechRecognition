%% =========================================================
% TESTARE LIVE CU MICROFON – WAVEFORM + 2 SPECTROGRAME
% =========================================================
% NECESAR ÎN WORKSPACE:
%   trainedNet
%   afe
%   TTrain
%   XTrain  (spectrograme: [H x W x 1 x N])
% =========================================================

clc; clearvars -except trainedNet afe TTrain XTrain; close all;

fs = 16000;
segmentSamples = 16000;
recObj = audiorecorder(fs,16,1);

disp("Apasă ENTER și vorbește 1 secundă...");
pause;
recordblocking(recObj,1.2);

%% === 1. AUDIO LIVE
x = getaudiodata(recObj);
x = x(:);

% forțare la 1 secundă
if length(x) < segmentSamples
    x = [x; zeros(segmentSamples-length(x),1)];
else
    startIdx = floor((length(x)-segmentSamples)/2)+1;
    x = x(startIdx:startIdx+segmentSamples-1);
end

%% === 2. SPECTROGRAMĂ LIVE
spect_live = extract(afe, x);
spect_live = log10(spect_live + 1e-6);

%% === 3. FORMAT CNN
spect4D = reshape(spect_live, size(spect_live,1), size(spect_live,2), 1, 1);

%% === 4. PREDICȚIE
scores = predict(trainedNet, spect4D);
classes = categories(TTrain);
[confidence, idx] = max(scores);
label = classes(idx);

%% === 5. SPECTROGRAMĂ CLASĂ RECUNOSCUTĂ (DIN XTrain)
idxAll = find(TTrain == label);                 % toate exemplele din clasă
spect_ref = mean(XTrain(:,:,1,idxAll), 4);     % template mediu

%% =================================================
% FIGURA 1 – WAVEFORM LIVE
figure('Name','Waveform LIVE','NumberTitle','off');
plot(x);
grid on;
title('Waveform semnal LIVE');
xlabel('Esantioane');
ylabel('Amplitudine');

%% =================================================
% FIGURA 2 – SPECTROGRAMĂ LIVE
figure('Name','Spectrogramă LIVE','NumberTitle','off');
imagesc(spect_live);
axis xy;
colormap jet;
colorbar;
title('Spectrogramă LIVE (input CNN)');
xlabel('Timp');
ylabel('Frecvență');

%% =================================================
% FIGURA 3 – SPECTROGRAMĂ CLASĂ RECUNOSCUTĂ
figure('Name','Spectrogramă CLASĂ','NumberTitle','off');
imagesc(spect_ref);
axis xy;
colormap jet;
colorbar;

title(['Spectrogramă CLASĂ RECUNOSCUTĂ: ', char(label), ...
       ' | Scor: ', num2str(confidence,'%.3f')]);

xlabel('Timp');
ylabel('Frecvență');

%% =================================================
% REDARE AUDIO
sound(x, fs);

%% =================================================
% MESAJ CONSOLĂ
disp("=============================================");
disp("CLASĂ PREZISĂ: " + string(label));
disp("SCOR: " + num2str(confidence,'%.4f'));
disp("=============================================");
