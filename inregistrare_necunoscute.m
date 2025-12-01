%% --- SCRIPT COMPLET: COLECTAREA DATELOR NECUNOSCUTE (ROMÂNĂ) ---
% Ruleaza automat in doua faze: Antrenare (30 de cuvinte unice) si Validare (10 cuvinte unice).

% =========================================================================
% 1. CONFIGURARE INITIALA
% =========================================================================

fs = 16e3; % Frecventa de esantionare (16 kHz)
segmentDuration = 1; 
segmentSamples = round(segmentDuration * fs); 
recObj = audiorecorder(fs, 16, 1); 

datasetFolder = fullfile(pwd,"ComandaMea"); 

disp("==========================================================");
disp("PROIECT: ComandaMea - Colectare Cuvinte Necunoscute (ROMÂNĂ)");
disp("!!! ATENȚIE: Rostiți cuvintele CLAR, diferit de comenzi. !!!");
disp("==========================================================");

% =========================================================================
% 2. LISTELE DE CUVINTE (Unice pentru Antrenare si Validare)
% =========================================================================

% 30 de cuvinte UNICE pentru Antrenare (TRAIN)
cuvinte_train = [
    "masa", "scaun", "telefon", "astazi", "acolo", "mereu", "carte", "scoala", "verde", "albastru", ...
    "numai", "niciodata", "frumos", "repede", "incet", "tata", "mama", "poate", "totul", "nimic", ...
    "timp", "ore", "zile", "saptamana", "luna", "an", "nou", "vechi", "rosu", "galben"
];

% 10 cuvinte UNICE pentru Validare (VALIDATION)
cuvinte_validation = [
    "avion", "drum", "stropi", "ploaie", "cer", "noapte", "ziua", "cald", "rece", "suflet"
];

% =========================================================================
% 3. FUNCTIE INTERNA PENTRU INREGISTRARE (Nu modificati)
% =========================================================================

function colecteaza_unknown(cuvinte_list, targetFolder, recObj, segmentSamples, fs, prefix)
    
    if ~exist(targetFolder, 'dir')
        disp("ATENTIE: Folderul necunoscut (" + targetFolder + ") nu exista. Il cream acum.");
        mkdir(targetFolder);
    end

    numExemple = numel(cuvinte_list);
    contor_global = 1;
    
    % Asigura unicitatea numelui fisierului
    existing_files = dir(fullfile(targetFolder, ['*.unknown_' + prefix + '_ro_*.wav']));
    if ~isempty(existing_files)
        contor_global = length(existing_files) + 1;
    end
    
    disp("----------------------------------------------------------");
    disp("Începem înregistrarea pentru: " + targetFolder);
    disp("----------------------------------------------------------");

    for i = 1:numExemple
        cmd = cuvinte_list{i};
        disp("Cuvant (" + i + "/" + numExemple + "): " + upper(cmd) + " - Vorbește ACUM!");
        
        recordblocking(recObj, 1.5); 
        x = getaudiodata(recObj); x = x(:);
        
        len = length(x);
        startIdx = floor((len - segmentSamples)/2) + 1;
        x = x(startIdx:startIdx + segmentSamples - 1);
        x = x / (max(abs(x)) + 1e-6);
        
        filename = fullfile(targetFolder, "unknown_" + prefix + "_ro_" + contor_global + ".wav");
        audiowrite(filename, x, fs);
        disp("Salvat: " + filename);
        
        contor_global = contor_global + 1;
        pause(0.2); 
    end
    disp("--- Faza " + upper(prefix) + " finalizată. ---");
end


% =========================================================================
% 4. RULAREA FAZELOR (Antrenare si Validare)
% =========================================================================

% 4A. Colectare set de Antrenare (TRAIN/unknown)
targetFolder_train = fullfile(datasetFolder, "train", "unknown");
colecteaza_unknown(cuvinte_train, targetFolder_train, recObj, segmentSamples, fs, "train");

% 4B. Colectare set de Validare (VALIDATION/unknown)
targetFolder_validation = fullfile(datasetFolder, "validation", "unknown");
colecteaza_unknown(cuvinte_validation, targetFolder_validation, recObj, segmentSamples, fs, "val");


% =========================================================================
% 5. INSTRUCTIUNI FINALE
% =========================================================================

disp(" ");
disp("==========================================================");
disp("!!! COLECTARE CUVINTE NECUNOSCUTE COMPLETĂ !!!");
disp("==========================================================");
disp("Acum trebuie doar să vă asigurați că ați copiat manual:");
disp(" ");
disp("1. Fisierele de zgomot (Google) in folderul: " + fullfile(datasetFolder, "background"));
disp("2. Fisierele de cuvinte în engleză (Google) in folderele 'unknown' create mai sus.");
disp(" ");
disp("Setul de date este finalizat si gata pentru antrenare.");