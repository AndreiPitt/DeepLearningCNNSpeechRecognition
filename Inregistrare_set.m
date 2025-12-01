%% --- SCRIPT COMPLET PENTRU COLECTAREA DATELOR VOCALE (ComandaMea) ---
% Versiune ROBUSTĂ: Asigură lungimea corectă a fișierelor și pauze clare.

% =========================================================================
% 1. CONFIGURAREA INITIALA
% =========================================================================

fs = 16e3; % Frecventa de esantionare (16 kHz)
segmentDuration = 1; % Durata fiecarui clip (1 secunda)
segmentSamples = round(segmentDuration * fs); % Numarul de esantioane (16000)
recObj = audiorecorder(fs, 16, 1); % Obiectul de înregistrare (Microfonul)
pauseTime = 1.5; % Pauza intre inregistrari

% --- Configurarea tonului de start ---
toneFreq = 1000; % Frecventa tonului in Hz
toneDuration = 0.15; % Durata tonului in secunde
t = linspace(0, toneDuration, round(fs * toneDuration));
toneSignal = 0.5 * sin(2 * pi * toneFreq * t)'; % Generare semnal sinusoidal
% ------------------------------------

% COMENZILE TALE:
comenzi = categorical(["masina","casa","dreapta","stanga","da","nu"]);

% FOLDERUL PRINCIPAL:
datasetFolder = fullfile(pwd,"ComandaMea"); 

disp("===========================================================");
disp("PROIECT: ComandaMea - COLECTARE DATE LIVE (ROBUST)");
disp("!!! ATENȚIE: Rostiți comanda IMEDIAT după tonul scurt! !!!");
disp("===========================================================");

% =========================================================================
% 2. FUNCTIE INTERNA PENTRU INREGISTRARE (NU MODIFICATI)
% =========================================================================

function colecteaza_date(comenzi, numExemple, targetFolder, recObj, segmentDuration, segmentSamples, fs, pauseTime, prefix, toneSignal)
    
    if ~exist(targetFolder, 'dir')
        mkdir(targetFolder);
    end
    
    numComenzi = numel(comenzi);
    contor_global = 1;
    
    for i = 1:numComenzi
        comandaCurenta = char(comenzi(i));
        folderCurent = fullfile(targetFolder, comandaCurenta);
        
        if ~exist(folderCurent, 'dir')
            mkdir(folderCurent);
        end
        
        for exempluIdx = 1:numExemple
            
            disp(' ');
            disp(['--- Faza ' upper(prefix) ' | Comanda: ' upper(comandaCurenta) ' | Exemplu ' num2str(exempluIdx) '/' num2str(numExemple) ' ---']);
            
            % 1. Semnal audio de pregătire (BIP)
            sound(toneSignal, fs); 
            disp('*** Rostiți acum! ***');
            
            % 2. Înregistrare fixă (1.0s)
            recordblocking(recObj, segmentDuration);
            audioData = getaudiodata(recObj);
            
            % 3. ROBUSTETE: Asigură exact 16000 de eșantioane
            currentSamples = length(audioData);
            if currentSamples > segmentSamples
                % Trunchiere (tăiere)
                audioData = audioData(1:segmentSamples);
                disp(['  [INFO] Fila a fost tăiată de la ' num2str(currentSamples) ' la 16000 esantioane.']);
            elseif currentSamples < segmentSamples
                % Padding (umplere cu zerouri)
                padding = segmentSamples - currentSamples;
                audioData = [audioData; zeros(padding, 1)];
                disp(['  [INFO] Fila a fost umplută de la ' num2str(currentSamples) ' la 16000 esantioane.']);
            end
            
            % 4. Salvare fișier - CORECTIA ESTE AICI
            afn = string(comandaCurenta) + "_" + prefix + num2str(contor_global) + ".wav";
            audiowrite(fullfile(folderCurent, afn), audioData, fs);
            
            contor_global = contor_global + 1;
            
            % Pauză clară pentru a vă pregăti
            pause(pauseTime); 
        end
    end
    disp(['--- Faza ' upper(prefix) ' finalizată cu ' num2str(contor_global-1) ' fișiere salvate. ---']);
end

% =========================================================================
% 3. RULAREA FAZELOR (Antrenare si Validare)
% =========================================================================

% 3A. INREGISTRAREA SETULUI DE ANTRENARE (TRAIN)
numExemple_train = 60; 
targetFolder_train = fullfile(datasetFolder, "train"); 
colecteaza_date(comenzi, numExemple_train, targetFolder_train, recObj, segmentDuration, segmentSamples, fs, pauseTime, "train", toneSignal); % Argument adaugat

% 3B. INREGISTRAREA SETULUI DE VALIDARE (VALIDATION)
numExemple_validation = 15; 
targetFolder_validation = fullfile(datasetFolder, "validation"); 
colecteaza_date(comenzi, numExemple_validation, targetFolder_validation, recObj, segmentDuration, segmentSamples, fs, pauseTime, "validation", toneSignal); % Argument adaugat

% =========================================================================
% 4. INSTRUCTIUNI FINALE
% =========================================================================
disp(" ");
disp("============================================================");
disp("!!! COLECTARE COMENZI COMPLETĂ. VA URMA 'NECUNOSCUTE' !!!");
disp("============================================================");