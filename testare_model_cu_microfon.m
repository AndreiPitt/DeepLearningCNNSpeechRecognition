%% --- TESTARE LIVE CU MICROFONUL ---

% Asigurati-va ca variabilele trainedNet, afe, fs, TTrain (sau classes) exista in Workspace!

% Parametri
fs = 16e3; % Frecventa de esantionare
segmentSamples = 16000; % Numarul de esantioane (1 secunda)
recObj = audiorecorder(fs, 16, 1); % Obiectul de înregistrare

disp("==========================================================");
disp(">>> MOD DE TESTARE LIVE (Spune o Comandă sau un Cuvânt Necunoscut) <<<");
disp("Apasă pe Enter pentru a începe înregistrarea...");
pause; % Așteaptă apăsarea tastei Enter

% 1. Înregistrare
disp("Vorbește ACUM (1 secundă):");
recordblocking(recObj, 1.2); % Înregistrează 1.2 secunde, pentru siguranță

x = getaudiodata(recObj); 
x = x(:);

% 2. Pre-procesare (Trunchiere/Padding la 1.0 sec)
% Asigurarea ca semnalul are exact 1 secunda
if length(x) < segmentSamples
    x = [x; zeros(segmentSamples - length(x), 1)];
else
    % Trunchierea centrului de 1s (similar cu inregistrarea initiala)
    len = length(x);
    startIdx = floor((len - segmentSamples)/2) + 1;
    x = x(startIdx:startIdx + segmentSamples - 1);
end

% 3. Extracția Spectrogramei (Caracteristicile)
% Se folosește 'afe' (Audio Feature Extractor) din faza de antrenare
spect = extract(afe, x);
spect = log10(spect + 1e-6);

% 4. Formatarea pentru CNN (4D)
spect4D = reshape(spect, [size(spect, 1), size(spect, 2), 1, 1]);

% 5. Predictia
scores = predict(trainedNet, spect4D); 
classes = categories(TTrain); % Reiau categoriile din variabila TTrain
label = scores2label(scores, classes, "auto");
[maxScore, ~] = max(scores);

% 6. Afișarea Rezultatului
disp("--- Rezultat Predicție ---")
disp("Ai spus: (redare sunetul înregistrat)")
sound(x, fs); % Redă înregistrarea pentru verificare
disp("Modelul prezice: " + string(label))
disp("Încredere: " + num2str(maxScore, '%.4f'))
disp("==========================================================");

