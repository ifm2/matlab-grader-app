function [westernName, givenName, familyName, converted, hasHan] = chineseToPinyin(name)
%CHINESETOPINYIN Convert a Chinese name to searchable Western-order Pinyin.
%   Uses the offline Python package pypinyin. Chinese family names are moved
%   after the given name so the result matches the app's First/Last columns.
%   The original input remains unchanged in the report and is used for all
%   student and submission matching. If pypinyin is unavailable, return the
%   original text and CONVERTED=false.

    original = strtrim(string(name));
    westernName = original;
    givenName = firstNameToken(original);
    familyName = lastNameToken(original);
    converted = false;
    hasHan = containsHanCharacter(original);

    if strlength(original)==0 || ~hasHan
        return
    end

    [savedTranslation,hasSavedTranslation] = savedNameTranslation(original);
    if hasSavedTranslation
        westernName = savedTranslation;
        givenName = firstNameToken(westernName);
        familyName = lastNameToken(westernName);
        converted = ~containsHanCharacter(westernName);
        return
    end

    persistent pypinyinReady
    if isempty(pypinyinReady)
        try
            % MATLAB excludes the Python user site from sys.path by default.
            py.site.addsitedir(char(py.site.getusersitepackages()));
            py.importlib.import_module('pypinyin');
            pypinyinReady = true;
        catch
            pypinyinReady = false;
        end
    end
    if ~pypinyinReady
        return
    end

    try
        compactName = regexprep(char(original),'[\s　]+','');
        syllables = lower(strtrim(string(cell(py.pypinyin.lazy_pinyin(compactName)))));
        syllables = syllables(strlength(syllables)>0);
        if isempty(syllables)
            return
        end

        % Most Chinese surnames have one character. Account for common
        % two-character compound surnames when splitting First and Last.
        compoundSurnames = ["欧阳","上官","司马","诸葛","夏侯","东方", ...
            "独孤","南宫","皇甫","尉迟","公孙","慕容","司徒","司空", ...
            "令狐","长孙","宇文","闻人","端木","呼延","百里","东郭", ...
            "南门","西门","闾丘","左丘","公羊","仲孙","轩辕"];
        surnameLength = 1;
        for k = 1:numel(compoundSurnames)
            if startsWith(string(compactName),compoundSurnames(k))
                surnameLength = 2;
                break
            end
        end
        if numel(syllables)<surnameLength
            return
        end

        familyName = capitalizePinyin(join(syllables(1:surnameLength),''));
        givenName = capitalizePinyin(join(syllables(surnameLength+1:end),''));
        westernName = strtrim(givenName+" "+familyName);
        converted = ~containsHanCharacter(westernName);
    catch
        % Keep the app usable when Python or pypinyin is not configured.
    end
end

function [translation,found] = savedNameTranslation(original)
    persistent translationMap cachedFileDate
    translation = "";
    found = false;
    mapPath = fullfile(fileparts(mfilename('fullpath')),'real-data','NameTranslations.csv');
    fileInfo = dir(mapPath);
    if isempty(fileInfo)
        fileDate = NaN;
    else
        fileDate = fileInfo.datenum;
    end
    if isempty(translationMap) || isempty(cachedFileDate) || ...
            ~(isequaln(fileDate,cachedFileDate))
        translationMap = containers.Map('KeyType','char','ValueType','char');
        if isfile(mapPath)
            try
                saved = readtable(mapPath,'TextType','string','VariableNamingRule','preserve');
                vars = string(saved.Properties.VariableNames);
                nameCol = find(strcmpi(vars,'OriginalName'),1);
                translationCol = find(strcmpi(vars,'Translation'),1);
                if ~isempty(nameCol) && ~isempty(translationCol)
                    for k=1:height(saved)
                        source = strtrim(string(saved{ k,nameCol }));
                        value = strtrim(string(saved{ k,translationCol }));
                        if source~="" && value~=""
                            translationMap(char(source)) = char(value);
                        end
                    end
                end
            catch
                % An unreadable local map should not prevent report import.
            end
        end
        cachedFileDate = fileDate;
    end
    key = char(strtrim(string(original)));
    if isKey(translationMap,key)
        translation = string(translationMap(key));
        found = true;
    end
end

function tf = containsHanCharacter(value)
    codeUnits = double(char(value));
    tf = any((codeUnits>=hex2dec('3400') & codeUnits<=hex2dec('4DBF')) | ...
        (codeUnits>=hex2dec('4E00') & codeUnits<=hex2dec('9FFF')) | ...
        (codeUnits>=hex2dec('F900') & codeUnits<=hex2dec('FAFF')));
    for k = 1:numel(codeUnits)-1
        if codeUnits(k)>=hex2dec('D800') && codeUnits(k)<=hex2dec('DBFF') && ...
                codeUnits(k+1)>=hex2dec('DC00') && codeUnits(k+1)<=hex2dec('DFFF')
            codePoint = 65536 + (codeUnits(k)-hex2dec('D800'))*1024 + ...
                codeUnits(k+1)-hex2dec('DC00');
            if (codePoint>=hex2dec('20000') && codePoint<=hex2dec('2FA1F')) || ...
                    (codePoint>=hex2dec('30000') && codePoint<=hex2dec('323AF'))
                tf = true;
                return
            end
        end
    end
end

function value = capitalizePinyin(value)
    value = string(value);
    if strlength(value)>0
        value = upper(extractBetween(value,1,1))+extractAfter(value,1);
    end
end

function value = firstNameToken(name)
    tokens = split(strtrim(string(name)));
    value = tokens(1);
end

function value = lastNameToken(name)
    tokens = split(strtrim(string(name)));
    value = tokens(end);
end
