%% --- SCRIPT COMPLET PENTRU COLECTAREA DATELOR VOCALE (ComandaMea) ---
% Rulati acest script de la capat la sfarsit, fara intreruperi.

% =========================================================================
% 1. CONFIGURAREA INITIALA
% =========================================================================

fs = 16e3; % Frecventa de esantionare (16 kHz)
segmentDuration = 1; % Durata fiecarui clip (1 secunda)
segmentSamples = round(segmentDuration * fs); % Numarul de esantioane (16000)
recObj = audiorecorder(fs, 16, 1); % Obiectul de înregistrare (Microfonul)

% COMENZILE TALE:
comenzi = categorical(["masina","casa","dreapta","stanga","da","nu"]);

% FOLDERUL PRINCIPAL:
datasetFolder = fullfile(pwd,"ComandaMea"); 

disp("==========================================================");
disp("PROIECT: ComandaMea - COLECTARE DATE LIVE");
disp("Scriptul va rula automat in doua faze: Antrenare (40x) si Validare (10x).");
disp("==========================================================");

% =========================================================================
% 2. FUNCTIE INTERNA PENTRU INREGISTRARE (NU MODIFICATI)
% =========================================================================

function colecteaza_date(comenzi, numExemple, targetFolder, recObj, segmentSamples, fs, datasetType)
    disp(">>> START: Colectare set de " + upper(datasetType) + " (" + numExemple + "x/comanda) <<<");
    if strcmpi(datasetType, 'validation')
        disp("!!! ATENȚIE: Rostiti cuvintele UNIC, diferit de cele din TRAIN !!!");
    end

    for i = 1:numel(comenzi)
        cmd = string(comenzi(i));
        cmdFolder = fullfile(targetFolder, cmd);
        if ~exist(cmdFolder,'dir'); mkdir(cmdFolder); end 

        disp("----------------------------------------------------------");
        disp("Comanda: " + upper(cmd) + " - " + datasetType);
        
        for j = 1:numExemple
            disp("Exemplul " + j + "/" + numExemple + ": Vorbește ACUM!");
            recordblocking(recObj, 1.5); % Înregistrează 1.5 sec
            x = getaudiodata(recObj); x = x(:);
            
            % Taie centrul la 1 secunda (16000 esantioane)
            len = length(x);
            startIdx = floor((len - segmentSamples)/2) + 1;
            x = x(startIdx:startIdx + segmentSamples - 1);
            
            % Normalizeaza volumul
            x = x / (max(abs(x)) + 1e-6);
            
            % Salveaza fisierul
            filename = fullfile(cmdFolder, cmd + "_" + datasetType(1) + j + ".wav");
            audiowrite(filename, x, fs);
            disp("Salvat: " + filename);
            pause(0.2); 
        end
    end
    disp(">>> Colectare " + upper(datasetType) + " finalizată! <<<");
end

% =========================================================================
% 3. INREGISTRAREA SETULUI DE ANTRENARE (TRAIN)
% =========================================================================

numExemple_train = 40; 
targetFolder_train = fullfile(datasetFolder, "train"); 
colecteaza_date(comenzi, numExemple_train, targetFolder_train, recObj, segmentSamples, fs, "train");

% =========================================================================
% 4. INREGISTRAREA SETULUI DE VALIDARE (VALIDATION)
% =========================================================================

numExemple_validation = 10; 
targetFolder_validation = fullfile(datasetFolder, "validation"); 
colecteaza_date(comenzi, numExemple_validation, targetFolder_validation, recObj, segmentSamples, fs, "validation");

% =========================================================================
% 5. INSTRUCTIUNI FINALE
% =========================================================================

disp(" ");
disp("==========================================================");
disp("!!! COLECTARE COMPLETĂ. STRUCTURA ESTE PREGATITA !!!");
disp("==========================================================");
disp("Pentru a finaliza setul de date, trebuie să faceți manual următoarele:");
disp(" ");
disp("1. Creati folderul de zgomot: " + fullfile(datasetFolder, "background"));
disp("   - Mutati aici fisierele lungi de zgomot (din setul Google).");
disp(" ");
disp("2. Creati folderele pentru 'Necunoscute':");
disp("   - " + fullfile(targetFolder_train, "unknown"));
disp("   - " + fullfile(targetFolder_validation, "unknown"));
disp(" ");
disp("3. Mutati fisierele de 'unknown' (cuvintele in engleza) + cuvinte românești non-comandă în folderele 'unknown'.");
disp(" ");