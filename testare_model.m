[file, path] = uigetfile('*.wav', 'Selectează un fișier audio');
[x, fs] = audioread(fullfile(path, file));

x = x(:);
if length(x) < 16000
    x = [x; zeros(16000 - length(x), 1)];
else
    x = x(1:16000);
end

spect = extract(afe, x);
spect = log10(spect + 1e-6);

scores = predict(trainedNet, spect);
classes = categories(TTrain);
label = scores2label(scores, classes, "auto");

disp("Modelul prezice: " + string(label))
