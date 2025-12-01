%% --- SCRIPT COMPLET: COLECTAREA DATELOR NECUNOSCUTE (ROMÂNĂ) ---
% Versiune ROBUSTĂ: Asigură lungimea corectă a fișierelor și pauze clare.

% =========================================================================
% 1. CONFIGURARE INITIALA
% =========================================================================

fs = 16e3; % Frecventa de esantionare (16 kHz)
segmentDuration = 1; 
segmentSamples = round(segmentDuration * fs); 
recObj = audiorecorder(fs, 16, 1); 
pauseTime = 1.5; % Pauza intre inregistrari

datasetFolder = fullfile(pwd,"ComandaMea"); 

disp("============================================================");
disp("PROIECT: ComandaMea - Colectare Cuvinte Necunoscute (ROBUST)");
disp("!!! ATENȚIE: Rostiți cuvintele IMEDIAT după tonul scurt! !!!");
disp("============================================================");

% =========================================================================
% 2. LISTELE DE CUVINTE (Mărite pentru o bază mai solidă)
% =========================================================================

% 60 de cuvinte UNICE pentru Antrenare (TRAIN) - Mărit de la 30
cuvinte_train = [
    "masa", "scaun", "telefon", "astazi", "acolo", "mereu", "carte", "scoala", "verde", "albastru", ...
    "numai", "niciodata", "frumos", "rau", "repede", "incet", "dulce", "acru", "tare", "moale", ...
    "luminos", "intunecat", "ploaie", "soare", "iarna", "vara", "frunza", "floare", "animal", "om", ...
    "apa", "foc", "aer", "pamant", "zid", "usa", "geam", "pat", "dulap", "perna", ...
    "covor", "oglinda", "cheie", "clopot", "minge", "papuci", "sosete", "ceas", "oglinda", "stilou", ...
    "creion", "hartie", "lipici", "vopsea", "tractor", "avion", "tren", "vapor", "racheta", "bicicleta"
];

% 15 de cuvinte UNICE pentru Validare (VALIDATION) - Mărit de la 10
cuvinte_validation = [
    "cainele", "pisica", "urias", "pitic", "ziua", "noaptea", "vesel", "trist", "cald", "rece", ...
    "sare", "piper", "orez", "faina", "sticla"
];

% =========================================================================
% 3. FUNCTIE INTERNA PENTRU INREGISTRARE NECUNOSCUTĂ
% =========================================================================

function colecteaza_unknown(cuvinte, targetFolder, recObj, segmentDuration, segmentSamples, fs, pauseTime, prefix)
    
    folderCurent = fullfile(targetFolder, "unknown");
    if ~exist(folderCurent, 'dir')
        mkdir(folderCurent);
    end
    
    numCuvinte = numel(cuvinte);
    contor_global = 1;
    
    for i = 1:numCuvinte
        cuvantCurent = cuvinte(i);
        
        disp(' ');
        disp(['--- Faza ' upper(prefix) ' | Cuvant: "' cuvantCurent '" | Exemplu ' num2str(i) '/' num2str(numCuvinte) ' ---']);
        
        % 1. Semnal audio de pregătire (BIP)
        beep(0.2); 
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
        
        % 4. Salvare fișier
        afn = ['unknown_' prefix num2str(contor_global) '_' cuvantCurent '.wav'];
        audiowrite(fullfile(folderCurent, afn), audioData, fs);
        
        contor_global = contor_global + 1;
        
        % Pauză clară pentru a vă pregăti
        pause(pauseTime); 
    end
    disp(['--- Faza ' upper(prefix) ' finalizată cu ' num2str(contor_global-1) ' fișiere salvate. ---']);
end


% =========================================================================
% 4. RULAREA FAZELOR (Antrenare si Validare)
% =========================================================================

% 4A. Colectare set de Antrenare (TRAIN/unknown)
targetFolder_train = fullfile(datasetFolder, "train");
colecteaza_unknown(cuvinte_train, targetFolder_train, recObj, segmentDuration, segmentSamples, fs, pauseTime, "train");

% 4B. Colectare set de Validare (VALIDATION/unknown)
targetFolder_validation = fullfile(datasetFolder, "validation");
colecteaza_unknown(cuvinte_validation, targetFolder_validation, recObj, segmentDuration, segmentSamples, fs, pauseTime, "val");


% =========================================================================
% 5. INSTRUCTIUNI FINALE
% =========================================================================
disp(" ");
disp("============================================================");
disp("!!! COLECTARE CUVINTE NECUNOSCUTE COMPLETĂ !!!");
disp("============================================================");