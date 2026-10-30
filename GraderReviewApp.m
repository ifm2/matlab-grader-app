Warning: truncated output (original token count: 18650)
Total output lines: 1585

function app = GraderReviewApp()
% GraderReviewApp Local review tool for MATLAB Grader exports.
%   GraderReviewApp launches a browser-style MATLAB UI for filtering
%   "Best solution as of today" reports by local student-group data.
%
%   The app reads files selected by the instructor and does not upload them.

    report = table();
    groups = table();
    problemLinks = containers.Map('KeyType','char','ValueType','char');
    reportHasAttemptHistory = false;
    app = struct();

    fig = uifigure('Name','MATLAB Grader Review','Position',[100 100 1440 820]);
    fig.Color = [0.96 0.97 0.98];
    fileMenu=uimenu(fig,'Text','File');
    uimenu(fileMenu,'Text','Import Grader report…','MenuSelectedFcn',@(~,~)chooseReport());
    uimenu(fileMenu,'Text','Import student groups…','MenuSelectedFcn',@(~,~)chooseGroups());
    uimenu(fileMenu,'Text','Import Problem URLs…','MenuSelectedFcn',@(~,~)importProblemLinks());
    uimenu(fileMenu,'Text','Export view…','MenuSelectedFcn',@(~,~)exportView());
    filterMenu=uimenu(fig,'Text','Filter');
    groupMenu=uimenu(filterMenu,'Text','Groups');
    menuGroupNames=strings(0,1);
    groupMenuItems=gobjects(0,1);
    root = uigridlayout(fig,[4 1]);
    root.RowHeight = {72, 56, '1x', 28};
    root.Padding = [18 14 18 12];
    root.RowSpacing = 10;

    header = uigridlayout(root,[1 2]);
    header.Layout.Row = 1;
    header.ColumnWidth = {'1x', 360};
    headingGrid = uigridlayout(header,[2 1]);
    headingGrid.Layout.Column = 1;
    headingGrid.RowHeight = {34,24};
    headingGrid.Padding = [0 0 0 0];
    uilabel(headingGrid,'Text','Grader Review','FontSize',24,'FontWeight','bold');
    subtitle = uilabel(headingGrid,'Text','Review best solutions, filter by teaching group, and open failed solutions.','FontSize',13);
    subtitle.Layout.Row = 2;
    subtitle.VerticalAlignment = 'bottom';
    headerButtons = uigridlayout(header,[1 2]);
    headerButtons.Layout.Column = 2;
    headerButtons.ColumnWidth = {'1x','1x'};
    headerButtons.Padding = [0 0 0 0];
    loadSample = uibutton(headerButtons,'Text','Load sample data','ButtonPushedFcn',@(~,~)loadSampleData());
    loadSample.Layout.Column = 1;
    loadReal = uibutton(headerButtons,'Text','Load real data (temporary)','ButtonPushedFcn',@(~,~)loadRealData());
    loadReal.Layout.Column = 2;

    controls = uigridlayout(root,[1 3]);
    controls.Layout.Row = 2;
    controls.ColumnWidth = {250,'1x',205};
    controls.RowHeight = {48};
    controls.Padding = [0 0 0 0];
    controls.ColumnSpacing = 10;
    currentAssignment="All assignments";
    selectedGroups = "All groups";
    failedOnly = uicheckbox(controls,'Text','Show students with failed solutions only','Value',false,'ValueChangedFcn',@(~,~)refreshView());
    failedOnly.Layout.Column = 1;
    showChineseNames = uicheckbox(controls,'Text','Show Chinese characters','Value',false, ...
        'ValueChangedFcn',@(~,~)toggleOriginalNameColumn());
    showChineseNames.Layout.Column = 3;
    showChineseNames.Tooltip = 'Add the original student name to the table; First and Last remain in Pinyin.';
    statusLabel = uilabel(controls,'Text','Load sample data or choose a Grader report and group spreadsheet.','FontColor',[0.25 0.32 0.40]);
    statusLabel.Layout.Column = 2;

    content = uigridlayout(root,[1 2]);
    content.Layout.Row = 3;
    content.ColumnWidth = {'1.6x','0.8x'};
    content.ColumnSpacing = 12;
    resultsPanel = uipanel(content,'Title','Student Results');
    resultsPanel.Layout.Column = 1;
    resultGrid = uigridlayout(resultsPanel,[2 1]);
    resultGrid.RowHeight = {105,'1x'};
    resultGrid.Padding = [8 8 8 8];
    statsGrid = uigridlayout(resultGrid,[2 5]);
    statsGrid.ColumnWidth = {145,145,'1x','1x','1x'};
    statsGrid.Layout.Row = 1;
    statsGrid.RowHeight = {52,42};
    statsGrid.Padding = [0 0 4 4];
    overallStat = statLabel(statsGrid,1,1,'Average overall','—');
    completionStat = statLabel(statsGrid,1,2,'Completion','—');
    problemStats = gobjects(1,3);
    for statIndex=1:3
        problemStats(statIndex)=statLabel(statsGrid,1,statIndex+2,'Problem average','—');
    end
    groupCompletionLabel = uilabel(statsGrid,'Text','Completion by group: —','FontSize',11,'WordWrap','on');
    groupCompletionLabel.Layout.Row = 2;
    groupCompletionLabel.Layout.Column = [1 5];
    resultTable = uitable(resultGrid,'Data',table(),'ColumnSortable',true,'CellSelectionCallback',@onSelection);
    resultTable.Layout.Row = 2;
    resultTable.ColumnName = {};
    resultTable.ColumnWidth = 'auto';

    detailPanel = uipanel(content,'Title','Student and solution details');
    detailPanel.Layout.Column = 2;
    detailGrid = uigridlayout(detailPanel,[6 1]);
    detailGrid.RowHeight = {34,42,26,32,'1x',44};
    detailGrid.Padding = [12 10 12 10];
    selectedLabel = uilabel(detailGrid,'Text','Select a student row or problem score.','FontWeight','bold','WordWrap','on');
    selectedLabel.Layout.Row = 1;
    studentInfoLabel = uilabel(detailGrid,'Text','Student details will appear here.','WordWrap','on');
    studentInfoLabel.Layout.Row = 2;
    solutionHeading = uilabel(detailGrid,'Text','Select a problem score to preview its submitted code.','FontWeight','bold');
    solutionHeading.Layout.Row = 3;
    submissionNav = uigridlayout(detailGrid,[1 3]);
    submissionNav.Layout.Row=4;
    submissionNav.ColumnWidth={95,'1x',95};
    submissionNav.ColumnSpacing=6;
    submissionNav.Padding=[0 0 0 0];
    previousSubmissionButton=uibutton(submissionNav,'Text','← Previous', ...
        'Enable','off','Visible','off','ButtonPushedFcn',@(~,~)stepSubmission(-1));
    previousSubmissionButton.Layout.Column=1;
    submissionPositionLabel=uilabel(submissionNav,'Text','', ...
        'HorizontalAlignment','center','FontWeight','bold');
    submissionPositionLabel.Layout.Column=2;
    nextSubmissionButton=uibutton(submissionNav,'Text','Next →', ...
        'Enable','off','Visible','off','ButtonPushedFcn',@(~,~)stepSubmission(1));
    nextSubmissionButton.Layout.Column=3;
    solutionFrame=uipanel(detailGrid,'BorderType','line','BorderWidth',2, ...
        'BorderColor',[0.72 0.76 0.80]);
    solutionFrame.Layout.Row=5;
    solutionGrid=uigridlayout(solutionFrame,[1 1]);
    solutionGrid.Padding=[2 2 2 2];
    solutionText = uitextarea(solutionGrid,'Editable','off','Value',{'No solution selected.'},'FontName','Monospaced');
    solutionText.Layout.Row = 1;
    actionGrid=uigridlayout(detailGrid,[1 3]);
    actionGrid.Layout.Row=6;
    actionGrid.ColumnWidth={'1.2x','1x','1.2x'};
    actionGrid.ColumnSpacing=6;
    actionGrid.Padding=[0 0 0 0];
    openButton = uibutton(actionGrid,'Text','Open in browser','Enable','off','ButtonPushedFcn',@openSelected);
    openButton.Layout.Column = 1;
    printCodeButton=uibutton(actionGrid,'Text','Print code','Enable','off','ButtonPushedFcn',@printSelectedCode);
    printCodeButton.Layout.Column=2;
    generateReportButton=uibutton(actionGrid,'Text','Generate Report','Enable','off','ButtonPushedFcn',@generateStudentReport);
    generateReportButton.Layout.Column=3;

    selectedSolutionCode="";
    selectedSubmittedAt="";
    selectedScore=NaN;
    selectedProblemTitle="";
    selectedAssignment="";
    selectedAttemptCount=0;
    selectedAttemptRows=[];
    selectedAttemptIndex=0;
    failsCenterStyle=[];
    failsStyleApplied=false;

    footer = uilabel(root,'Text','Files stay on this computer. Synthetic sample records are provided for demonstration.','FontSize',11,'FontColor',[0.35 0.40 0.45]);
    footer.Layout.Row = 4;

    selectedStudent = "";
    selectedProblemUrl = "";
    currentSummary = table();

    loadSampleData();
    realFolder=fullfile(fileparts(mfilename('fullpath')),'real-data');
    if (isfile(fullfile(realFolder,'Lab 1 Post Lab Exercises (2).xlsx')) || ...
            isfile(fullfile(realFolder,'Lab 1 Post Lab Exercises (1).xlsx'))) && ...
            isfile(fullfile(realFolder,'StudentGroups2627.xlsx')) && isfile(fullfile(realFolder,'URL_database.xlsx'))
        loadRealData();
    end

    if nargout == 0
        clear app
    else
        app.Figure = fig;
        app.LoadSampleData = @loadSampleData;
        app.ImportReport = @loadReport;
        app.ImportGroups = @loadGroups;
        app.SetGroupFilter = @setGroupFilter;
        app.GenerateReportToFile = @generateReportToFile;
    end

    function chooseReport()
        [file,path] = uigetfile({'*.xlsx;*.xls;*.csv','Grader reports (*.xlsx, *.xls, *.csv)'},'Select MATLAB Grader report');
        if isequal(file,0), return; end
        loadReport(fullfile(path,file));
    end

    function chooseGroups()
        [file,path] = uigetfile({'*.xlsx;*.xls;*.csv','Student groups (*.xlsx, *.xls, *.csv)'},'Select student-group spreadsheet');
        if isequal(file,0), return; end
        loadGroups(fullfile(path,file));
    end

    function loadRealData()
        folder = fullfile(fileparts(mfilename('fullpath')),'real-data');
        reportPath = fullfile(folder,'Lab 1 Post Lab Exercises (2).xlsx');
        if ~isfile(reportPath), reportPath=fullfile(folder,'Lab 1 Post Lab Exercises (1).xlsx'); end
        groupsPath = fullfile(folder,'StudentGroups2627.xlsx');
        urlsPath = fullfile(folder,'URL_database.xlsx');
        missing = strings(0,1);
        if ~isfile(reportPath), missing(end+1)="Lab 1 Post Lab Exercises (1).xlsx"; end
        if ~isfile(groupsPath), missing(end+1)="StudentGroups2627.xlsx"; end
        if ~isfile(urlsPath), missing(end+1)="URL_database.xlsx"; end
        if ~isempty(missing)
            uialert(fig,'Missing file(s) in the real-data folder: '+strjoin(missing,', '),'Real data not found');
            return
        end
        try
            loadGroups(groupsPath);
            loadReport(reportPath);
            loadRealGroupCollegeJoin(groupsPath);
            loadRealProblemLinks(urlsPath,reportPath);
            statusLabel.Text = 'Loaded real course files from the local real-data folder. Student data stays on this computer.';
            refreshView();
        catch err
            uialert(fig,err.message,'Could not load real data');
        end
    end

    function loadRealGroupCollegeJoin(path)
        try
            S=readtable(path,'Sheet','Students','VariableNamingRule','preserve');
            C=readtable(path,'Sheet','Colleges','VariableNamingRule','preserve');
            sv=string(S.Properties.VariableNames); cv=string(C.Properties.VariableNames);
            sGroup=firstName(sv,["Group","GROUP"]); sCode=firstName(sv,["Code"]); sID=firstName(sv,["ID","Account"]);
            cCode=firstName(cv,["Code"]); cCollege=firstName(cv,["College"]);
            if sGroup=="" || sCode=="" || sID=="" || cCode=="" || cCollege=="", return; end
            ids=lower(strtrim(string(S.(sID))));
            rosterGroups=strtrim(string(S.(sGroup)));
            valid=~ismissing(ids) & strlength(ids)>0 & ids~="0" & rosterGroups~="0";
            S=S(valid,:);
            sc=upper(strtrim(string(S.(sCode)))); cc=upper(strtrim(string(C.(cCode))));
            college=strings(height(S),1);
            for j=1:height(S)
                match=find(cc==sc(j),1);
                if ~isempty(match) && ~ismissing(string(C.(cCollege)(match))) && strlength(string(C.(cCollege)(match)))>0
                    college(j)=string(C.(cCollege)(match));
                else
                    college(j)=sc(j);
                end
            end
            groups=table(string(S.(sGroup)),college,string(S.(sID)), ...
                'VariableNames',{'Group','College','Account'});
            refreshView();
        catch
            % Keep the first-sheet roster loaded if the optional college join is unavailable.
        end
    end

    function loadRealProblemLinks(path,reportPath)
        try
            R=readtable(reportPath,'VariableNamingRule','preserve');
            rv=string(R.Properties.VariableNames); assignmentCol=firstName(rv,["Assignment Title","AssignmentTitle"]);
            if assignmentCol=="", return; end
            assignments=unique(string(R.(assignmentCol)),'stable');
            U=readtable(path,'VariableNamingRule','preserve');
            uv=string(U.Properties.VariableNames);
            sheetCol=firstName(uv,["SheetName"]); titleCol=firstName(uv,["ProblemTitle"]); urlCol=firstName(uv,["ProblemURL"]);
            if sheetCol=="" || titleCol=="" || urlCol=="", return; end
            problemLinks=containers.Map('KeyType','char','ValueType','char');
            matchedAssignments=strings(0,1);
            for a=1:numel(assignments)
                assign=assignments(a);
                normalizedURLAssignment=lower(regexprep(string(U.(sheetCol)),'[^a-zA-Z0-9]',''));
                normalizedReportAssignment=lower(regexprep(assign,'[^a-zA-Z0-9]',''));
                rows=normalizedURLAssignment==normalizedReportAssignment | ...
                    contains(normalizedURLAssignment,normalizedReportAssignment) | ...
                    contains(normalizedReportAssignment,normalizedURLAssignment);
                rows=rows & ~ismissing(string(U.(titleCol))) & ~ismissing(string(U.(urlCol)));
                for j=find(rows)'
                    base=problemPageBase(U,j,urlCol);
                    [assignmentID,problemID]=problemMapIDs(U,j,urlCol);
                    if assignmentID~="" && problemID~=""
                        problemLinks(problemIDMapKey(assignmentID,problemID))=char(base);
                    end
                    problemLinks(char(normalizeKey(string(assign)+"|"+string(U.(titleCol)(j)))))=char(base);
                end
                if any(rows), matchedAssignments(end+1)=assign; end %#ok<AGROW>
            end
            if isempty(matchedAssignments)
                statusLabel.Text='Loaded real data; no URL database assignment matched the report title. Import a URL map manually.';
            else
                statusLabel.Text='Matched URL database entries for: '+strjoin(matchedAssignments,', ');
            end
        catch err
            statusLabel.Text="Loaded real report and groups; URL map could not be read: "+string(err.message);
        end
    end

    function loadReport(path)
        try
            report = readtable(path,'VariableNamingRule','preserve');
            reportHasAttemptHistory=hasRepeatedSubmissions(report);
            if ismember("Assignment Title",string(report.Properties.VariableNames))
                assignments=unique(string(report.('Assignment Title')),'stable');
            elseif ismember("AssignmentTitle",string(report.Properties.VariableNames))
                assignments=unique(string(report.AssignmentTitle),'stable');
            else
                assignments=strings(0,1);
            end
            if numel(assignments)==1
                currentAssignment=assignments(1);
            else
                currentAssignment="All assignments";
            end
            statusLabel.Text = "Loaded report: " + string(path) + ". Import a problem URL map if you need working solution links.";
            refreshView();
        catch err
            uialert(fig,err.message,'Could not read report');
        end
    end

    function loadGroups(path)
        try
            groups = readtable(path,'VariableNamingRule','preserve');
            statusLabel.Text = "Loaded group data: " + string(path);
            refreshView();
        catch err
            uialert(fig,err.message,'Could not read groups');
        end
    end

    function loadSampleData()
        folder = fullfile(fileparts(mfilename('fullpath')),'sample-data');
        reportPath = fullfile(folder,'FakeGraderReport.xlsx');
        groupPath = fullfile(folder,'FakeStudentGroups.xlsx');
        if ~isfile(reportPath) || ~isfile(groupPath) || ~isfile(fullfile(folder,'FakeProblemLinks.xlsx'))
            try
                createFakeGraderReviewData(folder);
            catch err
                uialert(fig,err.message,'Sample data unavailable');
                return
            end
        end
        loadGroups(groupPath);
        loadReport(reportPath);
        loadProblemLinks(fullfile(folder,'FakeProblemLinks.xlsx'));
        statusLabel.Text = 'Loaded synthetic demo records. No real student data is included.';
        refreshView();
    end

    function loadProblemLinks(path)
        if ~isfile(path), return; end
        try
            L = readtable(path,'VariableNamingRule','preserve');
            lv=string(L.Properties.VariableNames);
            titleCol=firstName(lv,["ProblemTitle","Problem Title"]);
            urlCol=firstName(lv,["ProblemURL","Problem URL"]);
            if urlCol=="", error('URL map needs a ProblemURL column.'); end
            assignmentCol=firstName(lv,["SheetName","Assignment","AssignmentTitle","Assignment Title"]);
            assignmentIDCol=firstName(lv,["Assignment ID","AssignmentID"]);
            problemIDCol=firstName(lv,["Problem ID","ProblemID"]);
            problemSetURLCol=firstName(lv,["ProblemSetURL","Problem Set URL"]);
            hasAssignmentID=assignmentIDCol~="" || problemSetURLCol~="";
            hasProblemID=problemIDCol~="" || normalizeKey(urlCol)=="problemurl";
            if titleCol=="" && ~(hasAssignmentID && hasProblemID)
                error('URL map needs ProblemTitle, or both Assignment ID and Problem ID columns.');
            end
            problemLinks = containers.Map('KeyType','char','ValueType','char');
            idMapCount=0;
            for ii = 1:height(L)
                base=problemPageBase(L,ii,urlCol);
                if titleCol~=""
                    title=string(L.(titleCol)(ii));
                    if assignmentCol~=""
                        mapKey=char(normalizeKey(string(L.(assignmentCol)(ii))+"|"+title));
                    else
                        mapKey=char(normalizeKey(title));
                    end
                    problemLinks(mapKey)=char(base);
                end
                [assignmentID,problemID]=problemMapIDs(L,ii,urlCol);
                if assignmentID~="" && problemID~=""
                    problemLinks(problemIDMapKey(assignmentID,problemID))=char(base);
                    idMapCount=idMapCount+1;
                end
            end
            if titleCol=="" && idMapCount==0
                error('URL map rows must contain valid Assignment IDs, Problem IDs, and Problem URLs.');
            end
            statusLabel.Text = "Loaded problem URL mappings: " + string(path);
        catch err
            uialert(fig,err.message,'Could not read problem URL map');
        end
    end

    function importProblemLinks()
        [file,path] = uigetfile({'*.xlsx;*.xls;*.csv','Problem URL map (*.xlsx, *.xls, *.csv)'},'Select problem URL map');
        if isequal(file,0), return; end
        loadProblemLinks(fullfile(path,file));
        refreshView();
    end

    function refreshView()
        if isempty(report) || height(report)==0
            resultTable.Data = table();
            return
        end
        try
            updateGroupOptions();
            R = makeStudentSummary(report,groups,problemLinks,reportHasAttemptHistory);
            if ismember("Assignment",string(R.Properties.VariableNames)) && currentAssignment~="All assignments"
                R = R(R.Assignment == currentAssignment,:);
            end
            if ~any(selectedGroups=="All groups")
                R = R(ismember(string(R.Group),selectedGroups),:);
            end
            if failedOnly.Value && ismember('FailedCount',R.Properties.VariableNames)
                R = R(R.FailedCount > 0,:);
            end
            currentSummary=R;
            displayTable=R;
            if ismember('StudentName',displayTable.Properties.VariableNames)
                if showChineseNames.Value
                    displayTable.Properties.VariableNames{'StudentName'}='OriginalName';
                    displayTable=placeOriginalNameAfterLast(displayTable);
                else
                    displayTable.StudentName=[];
                end
            end
            if ismember('Assignment',displayTable.Properties.VariableNames) && ...
                    currentAssignment~="All assignments"
                displayTable.Assignment=[];
            end
            resultTable.Data = displayTable;
            [shortHeaders,headerHelp]=makeProblemHeaders(displayTable.Properties.VariableNames,currentAssignment);
            resultTable.ColumnName = shortHeaders;
            resultTable.Tooltip=headerHelp;
            resultTable.ColumnWidth=makeColumnWidths(displayTable.Properties.VariableNames);
            applyFailsAlignment(displayTable.Properties.VariableNames);
            updateResultsTitle();
            updateStats(report);
            statusLabel.Text = sprintf('%d students shown. Failed solutions are based on Tests Passed < Total Tests.',height(R));
            if reportHasChineseNames(report) && ~pinyinLibraryAvailable()
                statusLabel.Text = statusLabel.Text + " Chinese names are unchanged: install pypinyin in MATLAB's Python environment to display Pinyin.";
            end
        catch err
            if ~isempty(err.stack)
                statusLabel.Text = "Could not prepare report (line " + err.stack(1).line + "): " + string(err.message);
            else
                statusLabel.Text = "Could not prepare report: " + string(err.message);
            end
        end
    end

    function toggleOriginalNameColumn()
        % Keep the visible row order intact when the table's columns change.
        data=resultTable.Data;
        if ~istable(data) || isempty(data) || isempty(currentSummary)
            refreshView();
            return
        end

        displayed=resultTable.DisplayData;
        if ~istable(displayed) || height(displayed)~=height(data)
            refreshView();
            return
        end

        rowOrder=matchDisplayedRows(data,displayed);
        currentSummary=currentSummary(rowOrder,:);
        data=data(rowOrder,:);

        if showChineseNames.Value
            if ismember('StudentName',currentSummary.Properties.VariableNames)
                originalNames=currentSummary.StudentName;
            elseif ismember('StudentName',data.Properties.VariableNames)
                originalNames=data.StudentName;
            else
                refreshView();
                return
            end
            if ismember('StudentName',data.Properties.VariableNames)
                data.Properties.VariableNames{'StudentName'}='OriginalName';
                data.OriginalName=originalNames;
            else
                data.OriginalName=originalNames;
            end
            data=placeOriginalNameAfterLast(data);
        elseif ismember('OriginalName',data.Properties.VariableNames)
            data.OriginalName=[];
        end

        resultTable.Data=data;
        [shortHeaders,headerHelp]=makeProblemHeaders(data.Properties.VariableNames,currentAssignment);
        resultTable.ColumnName=shortHeaders;
        resultTable.Tooltip=headerHelp;
        resultTable.ColumnWidth=makeColumnWidths(data.Properties.VariableNames);
        if failsStyleApplied
            removeStyle(resultTable,1);
            failsStyleApplied=false;
        end
        applyFailsAlignment(data.Properties.VariableNames);
    end

    function rowOrder=matchDisplayedRows(data,displayed)
        % Map sorted DisplayData rows to Data row indices; duplicates are stable.
        if width(data)~=width(displayed) || ...
                ~isequal(data.Properties.VariableNames,displayed.Properties.VariableNames)
            error('GraderReviewApp:DisplayDataMismatch', ...
                'The displayed rows do not match the table columns.');
        end

        keys=tableRowKeys(data);
        displayKeys=tableRowKeys(displayed);
        rowOrder=zeros(height(displayed),1);
        used=false(height(data),1);
        for row=1:height(displayed)
            candidates=find(~used & keys==displayKeys(row),1,'first');
            if isempty(candidates)
                error('GraderReviewApp:DisplayDataMismatch', ...
                    'Could not match a displayed student row to the table data.');
            end
            rowOrder(row)=candidates;
            used(candidates)=true;
        end
    end

    function keys=tableRowKeys(T)
        keys=strings(height(T),1);
        for row=1:height(T)
            fields=strings(1,width(T));
            for column=1:width(T)
                value=string(T.(T.Properties.VariableNames{column})(row,:));
                if ismissing(value), value="<missing>"; end
                fields(column)=string(strlength(value))+":"+value;
            end
            keys(row)=strjoin(fields,"|");
        end
    end

    function T=placeOriginalNameAfterLast(T)
        names=T.Properties.VariableNames;
        originalIndex=find(strcmp(names,'OriginalName'),1);
        lastIndex=find(strcmp(names,'Last'),1);
        if isempty(originalIndex) || isempty(lastIndex) || originalIndex==lastIndex+1
            return
        end
        names(originalIndex)=[];
        lastIndex=find(strcmp(names,'Last'),1);
        names=[names(1:lastIndex),{'OriginalName'},names(lastIndex+1:end)];
        T=T(:,names);
    end

    function applyFailsAlignment(variableNames)
        col=find(strcmp(variableNames,'FailedCount'),1);
        if isempty(col) || failsStyleApplied, return; end
        failsCenterStyle=uistyle('HorizontalAlignment','center');
        addStyle(resultTable,failsCenterStyle,'column',col);
        failsStyleApplied=true;
    end

    function updateResultsTitle()
        if currentAssignment=="All assignments"
            selectedAssignment="All assignments";
        else
            selectedAssignment=currentAssignment;
        end
        resultsPanel.Title=sprintf('Student Results for Group %s for Assignment %s', ...
            strjoin(selectedGroups,', '),selectedAssignment);
    end

    function updateStats(T)
        [allRows,problemNames,problemMean,overallMean,completionByGroup] = summarizeStats(T,groups,currentAssignment,selectedGroups);
        if isempty(allRows)
            overallStat.Text = 'Average overall | —';
            completionStat.Text = "Completion | —"+newline+"Avg submissions to correct | —";
            groupCompletionLabel.Text = 'Completion by group: —';
            statsGrid.ColumnWidth=repmat({'1x'},1,5);
            for q=1:numel(problemStats), if isgraphics(problemStats(q)), delete(problemStats(q)); end, end
            problemStats=gobjects(1,0);
            return
        end
        overallStat.Text = sprintf('Average overall | %.1f%%',overallMean);
        if isnan(allRows.CompletionRate)
            completionStat.Text = sprintf('Completion | %d/%d',allRows.Completed,allRows.Enrolled);
        else
            completionStat.Text = sprintf('Completion | %d/%d (%.1f%%)',allRows.Completed,allRows.Enrolled,allRows.CompletionRate);
        end
        avgAttempts=averageSubmissionsToCorrect(T,groups,currentAssignment,selectedGroups);
        if isnan(avgAttempts)
            completionStat.Text=string(completionStat.Text)+newline+"Avg submissions to correct | —";
            completionStat.Tooltip='Attempt averages require an All solutions report with repeated learner/problem rows.';
        else
            completionStat.Text=string(completionStat.Text)+newline+string(sprintf('Avg submissions to correct | %.1f',avgAttempts));
            completionStat.Tooltip='Mean submission number at which a learner first reached full marks, averaged over learner/problem pairs that reached full marks.';
        end
        requiredColumns=max(5,2+numel(problemNames));
        statsGrid.ColumnWidth=repmat({'1x'},1,requiredColumns);
        statsGrid.ColumnWidth{1}=145;
        statsGrid.ColumnWidth{2}=145;
        for q=1:numel(problemStats), if isgraphics(problemStats(q)), delete(problemStats(q)); end, end
        problemStats=gobjects(1,numel(problemNames));
        for q=1:numel(problemNames)
            problemStats(q)=statLabel(statsGrid,1,q+2,'Problem average','—');
        end
        groupCompletionLabel.Layout.Column=[1 requiredColumns];
        for q=1:numel(problemStats)
            problemStats(q).Text = sprintf('%s | %.1f%%',problemNames(q),problemMean(q));
        end
        groupCompletionLabel.Text = 'Completion by group: ' + strjoin(completionByGroup,'   ·   ');
    end

    function updateGroupOptions()
        items = strings(0,1);
        if ~isempty(groups) && height(groups)>0
            gv=string(groups.Properties.VariableNames);
            groupCol=firstName(gv,["GROUP","Group"]);
            if groupCol~=""
                items=unique(strtrim(string(groups.(groupCol))),'stable');
                items=items(items~="" & items~="0");
            end
        end
        if isempty(items) || any(selectedGroups=="All groups") || ~all(ismember(selectedGroups,items))
            selectedGroups="All groups";
        end
        if ~isequal(items,menuGroupNames)
            delete(groupMenu.Children);
            menuGroupNames=items;
            groupMenuItems=gobjects(numel(items)+1,1);
            groupMenuItems(1)=uimenu(groupMenu,'Text','All groups', ...
                'MenuSelectedFcn',@(~,~)setGroupFilter("All groups"));
            for k=1:numel(items)
                groupName=items(k);
                groupMenuItems(k+1)=uimenu(groupMenu,'Text',char(groupName), ...
                    'MenuSelectedFcn',@(~,~)toggleGroupSelection(groupName));
            end
        end
        for k=1:numel(groupMenuItems)
            if k==1
                isChecked=any(selectedGroups=="All groups");
            else
                isChecked=ismember(menuGroupNames(k-1),selectedGroups);
            end
            groupMenuItems(k).Checked=onOff(isChecked);
        end
    end

    function toggleGroupSelection(groupName)
        if any(selectedGroups=="All groups")
            requested=groupName;
        elseif any(selectedGroups==groupName)
            requested=selectedGroups(selectedGroups~=groupName);
            if isempty(requested), requested="All groups"; end
        else
            requested=[selectedGroups;groupName];
        end
        setGroupFilter(requested);
    end

    function setGroupFilter(requestedGroups)
        requestedGroups=unique(strtrim(string(requestedGroups(:))),'stable');
        if isempty(requestedGroups) || any(requestedGroups=="All groups")
            selectedGroups="All groups";
        else
            if isempty(groups) || height(groups)==0
                error('Import a student-group spreadsheet before filtering by group.');
            end
            groupCol=firstName(string(groups.Properties.VariableNames),["GROUP","Group"]);
            if groupCol=="", error('The group spreadsheet has no Group column.'); end
            available=unique(strtrim(string(groups.(groupCol))),'stable');
            if ~all(ismember(requestedGroups,available))
                error('Requested group filter contains a group not present in the imported roster.');
            end
            selectedGroups=requestedGroups;
        end
        updateGroupOptions();
        refreshView();
    end

    function [headers,helpText]=makeProblemHeaders(variableNames,assignment)
        headers=variableNames;
        helpLines=strings(0,1);
        for k=1:numel(variableNames)
            token=regexp(variableNames{k},'^Q_(\d+)_','tokens','once');
            if isempty(token)
                switch variableNames{k}
                    case 'TotalScore', headers{k}='Total %';
                    case 'PercentSubmitted', headers{k}='% Complete';
                    case 'ScoreOfSubmitted', headers{k}='Avg submitted %';
                    case 'FailedCount', headers{k}='Fails';
                    case 'ActiveTime', headers{k}='Active time';
                    case 'OriginalName', headers{k}='Original name';
                end
                continue
            end
            headers{k}=sprintf('Q%s',token{1});
            title=problemFromColumn(report,string(assignment),string(variableNames{k}));
            if title=="", title=string(variableNames{k}); end
            helpLines(end+1,1)=sprintf('Q%s = %s',token{1},title); %#ok<AGROW>
        end
        helpLines(end+1,1)='Active time adds gaps between submissions of up to 1 hour.';
        helpText=cellstr(helpLines);
    end

    function widths=makeColumnWidths(variableNames)
        widths=cell(1,numel(variableNames));
        for k=1:numel(variableNames)
            variable=variableNames{k};
            if startsWith(variable,'Q_')
                widths{k}=76;
            else
                switch variable
                    case 'Group', widths{k}=42;
                    case {'First','Last'}, widths{k}=72;
                    case 'College', widths{k}=55;
                    case 'TotalScore', widths{k}=58;
                    case 'PercentSubmitted', widths{k}=63;
                    case 'ScoreOfSubmitted', widths{k}=88;
                    case {'FirstQ','LastQ'}, widths{k}=84;
                    case 'ActiveTime', widths{k}=70;
                    case 'FailedCount', widths{k}=46;
                    case 'Assignment', widths{k}=115;
                    case 'OriginalName', widths{k}=145;
                    otherwise, widths{k}=75;
                end
            end
        end
    end

    function onSelection(~,event)
        if isempty(event.Indices) || isempty(resultTable.Data), return; end
        row = event.Indices(1,1);
        col = event.Indices(1,2);
        current = resultTable.Data;
        if ~istable(current) || row > height(current), return; end
        selectedStudent = "";
        selectedSolutionCode="";
        selectedSubmittedAt="";
        selectedScore=NaN;
        selectedProblemTitle="";
        selectedAssignment="";
        selectedAttemptCount=0;
        selectedAttemptRows=[];
        selectedAttemptIndex=0;
        summaryRow=[];
        if all(ismember({'First','Last','Group','College'},current.Properties.VariableNames)) && ...
                ~isempty(currentSummary) && row<=height(currentSummary)
            match=currentSummary.First==current.First(row) & currentSummary.Last==current.Last(row) & ...
                currentSummary.Group==current.Group(row) & currentSummary.College==current.College(row);
            if ismember('Assignment',current.Properties.VariableNames) && ismember('Assignment',currentSummary.Properties.VariableNames)
                match=match & currentSummary.Assignment==current.Assignment(row);
            end
            matchRows=find(match);
            if ~isempty(matchRows)
                summaryRow=matchRows(1);
                selectedStudent=string(currentSummary.StudentName(summaryRow));
            end
        elseif ismember('Student',current.Properties.VariableNames)
            selectedStudent = string(current.Student(row));
        end
        selectedAssignment="";
        if ismember('Assignment',current.Properties.VariableNames), selectedAssignment=string(current.Assignment(row)); end
        if selectedAssignment=="" && ~isempty(summaryRow) && ismember('Assignment',currentSummary.P…650 tokens truncated…ed solution row(s) for this problem in the current import.',attemptCount));
    end

    function stepSubmission(direction)
        if isempty(selectedAttemptRows), return; end
        selectedAttemptIndex=max(1,min(numel(selectedAttemptRows),selectedAttemptIndex+direction));
        updateSelectedAttempt();
    end

    function updateSelectedAttempt()
        if isempty(selectedAttemptRows) || selectedAttemptIndex<1 || ...
                selectedAttemptIndex>numel(selectedAttemptRows)
            return
        end
        rowIndex=selectedAttemptRows(selectedAttemptIndex);
        [solutionCode,score,submittedAt]=submissionDetails(report,rowIndex);
        selectedSolutionCode=solutionCode;
        selectedSubmittedAt=submittedAt;
        selectedScore=score;
        submissionPositionLabel.Text=sprintf('Submission %d of %d', ...
            selectedAttemptIndex,numel(selectedAttemptRows));
        if numel(selectedAttemptRows)>1
            previousSubmissionButton.Visible='on';
            nextSubmissionButton.Visible='on';
            previousSubmissionButton.Enable=onOff(selectedAttemptIndex>1);
            nextSubmissionButton.Enable=onOff(selectedAttemptIndex<numel(selectedAttemptRows));
        else
            previousSubmissionButton.Visible='off';
            previousSubmissionButton.Enable='off';
            nextSubmissionButton.Visible='off';
            nextSubmissionButton.Enable='off';
        end
        solutionHeading.Text=sprintf('%s score: %g%% | %s', ...
            selectedProblemTitle,selectedScore,selectedSubmittedAt);
        if strlength(solutionCode)==0
            solutionText.Value={'(No Solution column in this report.)'};
        else
            solutionText.Value=cellstr(splitlines(solutionCode));
        end
        if isfinite(selectedScore) && selectedScore<100
            solutionFrame.BorderColor=[0.85 0.20 0.20];
        else
            solutionFrame.BorderColor=[0.20 0.58 0.34];
        end
        selectedProblemUrl=solutionPageURL(report,rowIndex,selectedAssignment, ...
            selectedProblemTitle,problemLinks);
        openButton.Enable='off';
        if startsWith(lower(selectedProblemUrl),["http://","https://"])
            openButton.Enable='on';
        end
        if strlength(solutionCode)>0
            printCodeButton.Enable='on';
            generateReportButton.Enable='on';
        else
            printCodeButton.Enable='off';
            generateReportButton.Enable='off';
        end
    end

    function printSelectedCode(~,~)
        if strlength(selectedSolutionCode)==0
            uialert(fig,'This report does not contain solution code for the selected submission.','No code to print');
            return
        end
        try
            printPath=fullfile(tempdir,['GraderReviewPrint-' char(java.util.UUID.randomUUID) '.html']);
            metadata=selectedStudentMetadata();
            writePrintPage(printPath,metadata,selectedSolutionCode);
            web(printPath,'-browser');
        catch err
            uialert(fig,"Could not prepare the print page: "+string(err.message),'Print code failed');
        end
    end

    function metadata=selectedStudentMetadata()
        metadata=struct('Student',char(chineseToPinyin(selectedStudent)),'Group','','Assignment',char(selectedAssignment), ...
            'Problem',char(selectedProblemTitle),'Score',selectedScore,'Submitted',char(selectedSubmittedAt), ...
            'Attempts',selectedAttemptCount);
        if ~isempty(currentSummary) && ismember('StudentName',currentSummary.Properties.VariableNames)
            match=string(currentSummary.StudentName)==selectedStudent;
            if ismember('Assignment',currentSummary.Properties.VariableNames)
                match=match & string(currentSummary.Assignment)==selectedAssignment;
            end
            rows=find(match,1);
            if ~isempty(rows) && ismember('Group',currentSummary.Properties.VariableNames)
                metadata.Group=char(string(currentSummary.Group(rows)));
            end
        end
    end

    function generateStudentReport(~,~)
        if strlength(selectedSolutionCode)==0
            uialert(fig,'This report does not contain solution code for the selected submission.','No code to include');
            return
        end
        safeName=regexprep(char(chineseToPinyin(selectedStudent)+"_"+selectedProblemTitle),'[^A-Za-z0-9_-]','_');
        [file,path]=uiputfile('*.pdf',['StudentReview_' safeName '.pdf'],'Save student review PDF');
        if isequal(file,0), return; end
        try
            generateReportToFile(fullfile(path,file));
            web(fullfile(path,file),'-browser');
            statusLabel.Text="Saved student review PDF: "+string(fullfile(path,file));
        catch err
            uialert(fig,"Could not create the report: "+string(err.message),'Report generation failed');
        end
    end

    function generateReportToFile(outputPath)
        if strlength(selectedSolutionCode)==0
            error('Select a problem score with an available solution before generating a report.');
        end
        createStudentReviewPDF(outputPath,selectedStudentMetadata(),selectedSolutionCode);
    end

    function openSelected(~,~)
        if strlength(selectedProblemUrl)==0, return; end
        if ~startsWith(lower(selectedProblemUrl),["http://","https://"])
            uialert(fig,'The selected solution link is not a valid web address. Check the problem URL mapping.','Invalid solution URL');
            return
        end
        try
            web(char(selectedProblemUrl),'-browser');
        catch err
            uialert(fig,"Could not open the solution in the default browser: "+string(err.message),'Browser launch failed');
        end
    end

    function exportView()
        data = resultTable.Data;
        if ~istable(data) || isempty(data)
            uialert(fig,'There are no rows to export.','Export');
            return
        end
        [file,path] = uiputfile('GraderReview.xlsx','Export filtered results');
        if isequal(file,0), return; end
        try
            writetable(data,fullfile(path,file));
            statusLabel.Text = "Exported " + string(fullfile(path,file));
        catch err
            uialert(fig,err.message,'Export failed');
        end
    end
end

function R = makeStudentSummary(T,G,~,hasAttemptHistory)
% Normalize the supported Grader export columns and summarize by learner.
    vars = string(T.Properties.VariableNames);
    emailName = firstName(vars,["Student Email","StudentEmail","Email","Email Address"]);
    studentNameCol = firstName(vars,["Student Name","StudentName","Learner Name"]);
    passedCol = firstName(vars,["Tests Passed","TestsPassed"]);
    totalCol = firstName(vars,["Total Tests","TotalTests"]);
    timeCol = firstName(vars,["Submitted Time","SubmittedTime"]);
    problemCol = firstName(vars,["Problem Title","ProblemTitle"]);
    assignmentCol = firstName(vars,["Assignment Title","AssignmentTitle"]);
    if emailName=="" || passedCol=="" || totalCol==""
        error('Report needs student email, tests passed, and total tests columns.');
    end
    email = lower(strtrim(string(T.(emailName))));
    if studentNameCol==""
        studentName = email;
    else
        studentName = string(T.(studentNameCol));
    end
    passed = double(T.(passedCol));
    total = double(T.(totalCol));
    failed = passed < total;
    if timeCol~=""
        submitted = parseTimes(T.(timeCol));
    else
        submitted = NaT(height(T),1);
    end
    if problemCol=="", problem = repmat("Problem",height(T),1); else, problem = string(T.(problemCol)); end
    if assignmentCol=="", assignment = repmat("Assignment",height(T),1); else, assignment = string(T.(assignmentCol)); end
    if assignmentCol=="", assignment = repmat("Assignment",height(T),1); end
    studentAssignment = unique([email,assignment],'rows','stable');
    rows = struct([]);
    for s = 1:size(studentAssignment,1)
        studentKey=studentAssignment(s,1);
        assignmentKey=studentAssignment(s,2);
        idx = find(email==studentKey & assignment==assignmentKey);
        allIdx=idx;
        % Use the assignment-wide title set so every student's summary has
        % the same table columns, including problems they have not submitted.
        titles = unique(problem(assignment==assignmentKey),'stable');
        % Keep the newest row per problem, robustly, even if the export is not sorted.
        pkeys = unique(problem(idx),'stable');
        kept = [];
        for p = 1:numel(pkeys)
            candidates = allIdx(problem(allIdx)==pkeys(p));
            if any(~isnat(submitted(candidates)))
                [~,k] = max(submitted(candidates));
                kept(end+1) = candidates(k); %#ok<AGROW>
            else
                kept(end+1) = candidates(end); %#ok<AGROW>
            end
        end
        idx = kept;
        nm = studentName(idx(1));
        group = "?"; college = "?";
        if ~isempty(G) && height(G)>0
            gv = string(G.Properties.VariableNames);
            accountCol = firstName(gv,["Account","ID","SSO","Student ID"]);
            groupCol = firstName(gv,["GROUP","Group"]);
            collegeCol = firstName(gv,["College","Code"]);
            if accountCol~=""
                acct = lower(string(G.(accountCol)));
                emailAcct = extractBefore(studentKey+"@","@");
                match = acct==emailAcct | acct==studentKey;
                if any(match)
                    if groupCol~="", group=string(G.(groupCol)(find(match,1))); end
                    if collegeCol~="", college=string(G.(collegeCol)(find(match,1))); end
                end
            end
        end
        subPassed = passed(idx); subTotal = total(idx);
        questionScores=100*subPassed./max(subTotal,1);
        submittedCount=numel(unique(problem(idx),'stable'));
        if isempty(questionScores) || all(isnan(questionScores)), score=0; else, score=round(mean(questionScores,'omitnan')); end
        numProblems=max(numel(titles),1);
        overallScore=round(sum(questionScores,'omitnan')/numProblems);
        submittedRows = allIdx(~isnat(submitted(allIdx)));
        if isempty(submittedRows), firstTime=""; lastTime="";
        else
            firstTime=string(datetime(min(submitted(submittedRows)),'Format','dd-MMM HH:mm'));
            lastTime=string(datetime(max(submitted(submittedRows)),'Format','dd-MMM HH:mm'));
        end
        allStudentTimes=submitted(allIdx);
        activeTime=formatActiveTime(allStudentTimes);
        [~,first,last]=chineseToPinyin(nm);
        row = struct('Group',group,'StudentName',nm,'First',first,'Last',last, ...
            'College',college,'TotalScore',overallScore,'PercentSubmitted',round(100*submittedCount/numProblems), ...
            'ScoreOfSubmitted',score,'FirstQ',firstTime,'LastQ',lastTime,'ActiveTime',activeTime, ...
            'FailedCount',sum(failed(idx)));
        row.Assignment=assignmentKey;
        for p=1:numel(titles)
            safe=matlab.lang.makeValidName("Q_"+string(p)+"_"+titles(p));
            j=idx(problem(idx)==titles(p));
            allProblemRows=allIdx(problem(allIdx)==titles(p));
            val="";
            if ~isempty(j)
                val=string(round(100*passed(j(1))/max(total(j(1)),1)))+"%";
                if hasAttemptHistory && numel(allProblemRows)>1, val=val+" ("+numel(allProblemRows)+")"; end
            end
            row.(safe)=val;
        end
        rows = [rows; row]; %#ok<AGROW>
    end
    if isempty(rows), R=table(); else, R=struct2table(rows); R=sortrows(R,{'Group','StudentName'}); end
end

function tf = hasRepeatedSubmissions(T)
    tf=false;
    vars=string(T.Properties.VariableNames);
    emailCol=firstName(vars,["Student Email","StudentEmail","Email","Email Address"]);
    problemCol=firstName(vars,["Problem Title","ProblemTitle"]);
    assignmentCol=firstName(vars,["Assignment Title","AssignmentTitle"]);
    if emailCol=="" || problemCol=="", return; end
    email=lower(strtrim(string(T.(emailCol))));
    problem=strtrim(string(T.(problemCol)));
    if assignmentCol=="", assignment=repmat("Assignment",height(T),1); else, assignment=strtrim(string(T.(assignmentCol))); end
    valid=email~="" & problem~="" & ~ismissing(email) & ~ismissing(problem);
    keys=[email(valid),assignment(valid),problem(valid)];
    if isempty(keys), return; end
    [~,~,groupIndex]=unique(keys,'rows');
    tf=any(accumarray(groupIndex,1)>1);
end

function label = formatActiveTime(times)
    times=times(~isnat(times));
    times=sort(times);
    if numel(times)<2, label='—'; return; end
    gaps=minutes(diff(times));
    activeMinutes=sum(gaps(gaps<=60 & gaps>=0));
    roundedMinutes=round(activeMinutes);
    hours=floor(roundedMinutes/60);
    remainingMinutes=mod(roundedMinutes,60);
    if hours>0
        label=sprintf('%dh %02dm',hours,remainingMinutes);
    else
        label=sprintf('%d min',remainingMinutes);
    end
end

function h = statLabel(parent,row,col,label,value)
    h=uilabel(parent,'Text',label+" | "+value,'FontSize',13,'FontWeight','bold','WordWrap','on');
    h.Layout.Row=row;
    h.Layout.Column=col;
end

function problemTitle = problemFromColumn(T,assignment,columnName)
    problemTitle="";
    v=string(T.Properties.VariableNames);
    problemCol=firstName(v,["Problem Title","ProblemTitle"]);
    assignmentCol=firstName(v,["Assignment Title","AssignmentTitle"]);
    if problemCol=="", return; end
    problem=string(T.(problemCol));
    if assignmentCol~=""
        assignmentValues=string(T.(assignmentCol));
        titles=unique(problem(assignmentValues==string(assignment)),'stable');
    else
        titles=unique(problem,'stable');
    end
    for k=1:numel(titles)
        expected=string(matlab.lang.makeValidName("Q_"+string(k)+"_"+titles(k)));
        if expected==columnName
            problemTitle=titles(k);
            return
        end
    end
end

function [attemptRows,attemptCount] = findSelectedAttempts(T,student,assignment,problemTitle)
    attemptRows=[]; attemptCount=0;
    v=string(T.Properties.VariableNames);
    nameCol=firstName(v,["Student Name","StudentName","Learner Name"]);
    emailCol=firstName(v,["Student Email","StudentEmail","Email","Email Address"]);
    assignmentCol=firstName(v,["Assignment Title","AssignmentTitle"]);
    problemCol=firstName(v,["Problem Title","ProblemTitle"]);
    timeCol=firstName(v,["Submitted Time","SubmittedTime"]);
    if problemCol=="", return; end
    if nameCol~="", names=string(T.(nameCol)); else, names=repmat("",height(T),1); end
    if emailCol~="", emails=lower(strtrim(string(T.(emailCol)))); else, emails=repmat("",height(T),1); end
    mask=names==string(student) | emails==lower(string(student));
    if assignmentCol~="", mask=mask & string(T.(assignmentCol))==string(assignment); end
    mask=mask & string(T.(problemCol))==string(problemTitle);
    candidates=find(mask);
    attemptCount=numel(candidates);
    if isempty(candidates), return; end
    if timeCol~=""
        times=parseTimes(T.(timeCol));
        dated=candidates(~isnat(times(candidates)));
        undated=candidates(isnat(times(candidates)));
        if ~isempty(dated)
            sortKeys=[datenum(times(dated)),double(dated)]; %#ok<DATNM>
            [~,order]=sortrows(sortKeys,[1 2]);
            dated=dated(order);
        end
        attemptRows=[dated;undated];
    else
        attemptRows=candidates;
    end
end

function [solutionCode,score,submittedAt] = submissionDetails(T,rowIndex)
    solutionCode=""; score=NaN; submittedAt="";
    v=string(T.Properties.VariableNames);
    solutionCol=firstName(v,["Solution","Learner Solution"]);
    scoreCol=firstName(v,["% Score","Assessment Test Score","Score"]);
    passCol=firstName(v,["Tests Passed","TestsPassed"]);
    totalCol=firstName(v,["Total Tests","TotalTests"]);
    timeCol=firstName(v,["Submitted Time","SubmittedTime"]);
    if solutionCol~="", solutionCode=string(T.(solutionCol)(rowIndex)); end
    if scoreCol~=""
        rawScore=T.(scoreCol)(rowIndex,:);
        if iscell(rawScore), rawScore=rawScore{1}; end
        score=str2double(erase(strtrim(string(rawScore)),"%"));
    end
    if ~isfinite(score) && passCol~="" && totalCol~=""
        score=100*double(T.(passCol)(rowIndex))/max(double(T.(totalCol)(rowIndex)),1);
    end
    if timeCol~=""
        times=parseTimes(T.(timeCol)(rowIndex,:));
        if ~isempty(times) && ~isnat(times(1))
            submittedAt=string(datetime(times(1),'Format','dd-MMM-yyyy HH:mm'));
        end
    end
end

function value=onOff(tf)
    if tf, value='on'; else, value='off'; end
end

function createStudentReviewPDF(outputPath,metadata,solutionCode)
% Create a compact, one-page A4 review sheet. HTML is used for compact code
% layout, inside the Report API PDF container.
    import mlreportgen.report.Report
    import mlreportgen.dom.PageSize
    import mlreportgen.dom.PageMargins
    import mlreportgen.dom.HTML

    if ~endsWith(lower(string(outputPath)),'.pdf')
        error('The report output filename must end in .pdf.');
    end
    code=char(solutionCode);
    codeLines=splitlines(string(code));
    charsPerInchWidth=(8.27-0.76)*72/0.60;
    linesAt7=sum(max(1,ceil(strlength(codeLines)/(charsPerInchWidth/7.0))));
    linesAt62=sum(max(1,ceil(strlength(codeLines)/(charsPerInchWidth/6.2))));
    linesAt48=sum(max(1,ceil(strlength(codeLines)/(charsPerInchWidth/4.8))));
    if linesAt7<=65
        codeFont=7.0;
    elseif linesAt62<=80
        codeFont=6.2;
    elseif linesAt48<=100
        codeFont=4.8;
    else
        error('This solution is too long to fit legibly on one A4 page. The PDF was not created.');
    end
    scoreText='';
    if isfield(metadata,'Score') && isfinite(metadata.Score), scoreText=sprintf('%.0f%%',metadata.Score); end
    attemptsText='';
    if isfield(metadata,'Attempts') && metadata.Attempts>0, attemptsText=sprintf('%d',metadata.Attempts); end
    details={ ...
        'Student', getMetadataField(metadata,'Student');
        'Group', getMetadataField(metadata,'Group');
        'Assignment', getMetadataField(metadata,'Assignment');
        'Problem', getMetadataField(metadata,'Problem');
        'Score', scoreText;
        'Submitted', getMetadataField(metadata,'Submitted');
        'Submission rows', attemptsText};
    detailHtml='';
    for k=1:size(details,1)
        if isempty(details{k,2}), continue; end
        detailHtml=[detailHtml '<span class="label">' escapeHtml(details{k,1}) ':</span> ' ...
            '<span>' escapeHtml(details{k,2}) '</span><br/>']; %#ok<AGROW>
    end
    html=['<html><head><meta charset="utf-8"/><style>' ...
        '@page{size:A4 portrait;margin:8mm;}body{font-family:Arial,sans-serif;color:#17212b;margin:0;}' ...
        'h1{font-size:15pt;margin:0 0 4pt 0;} .meta{font-size:8pt;line-height:1.18;margin:0 0 6pt 0;}' ...
        '.label{font-weight:bold;}h2{font-size:9pt;margin:4pt 0 2pt 0;}' ...
        'pre{font-family:Consolas,"Courier New",monospace;font-size:' num2str(codeFont) 'pt;' ...
        'line-height:0.98;white-space:pre-wrap;overflow-wrap:anywhere;margin:0;}' ...
        '</style></head><body><h1>Student solution review</h1><div class="meta">' ...
        detailHtml '</div><h2>Submitted solution</h2><pre>' escapeHtml(code) '</pre></body></html>'];
    rpt=Report(char(outputPath),'pdf');
    cleanup=onCleanup(@()closeReportIfOpen(rpt));
    rpt.Layout.PageSize=PageSize('11.69in','8.27in','portrait');
    margins=PageMargins();
    margins.Top='0.32in'; margins.Bottom='0.32in';
    margins.Left='0.38in'; margins.Right='0.38in';
    rpt.Layout.PageMargins=margins;
    append(rpt,HTML(html));
    close(rpt);
    clear cleanup
    d=dir(outputPath);
    if isempty(d) || d.bytes<500
        error('The PDF report was not written successfully.');
    end
end

function writePrintPage(outputPath,metadata,solutionCode)
    scoreText='';
    if isfield(metadata,'Score') && isfinite(metadata.Score), scoreText=sprintf('%.0f%%',metadata.Score); end
    details=sprintf('<b>%s</b> &nbsp; Group %s &nbsp; %s / %s &nbsp; Score %s &nbsp; Submitted %s', ...
        escapeHtml(getMetadataField(metadata,'Student')),escapeHtml(getMetadataField(metadata,'Group')), ...
        escapeHtml(getMetadataField(metadata,'Assignment')),escapeHtml(getMetadataField(metadata,'Problem')), ...
        scoreText,escapeHtml(getMetadataField(metadata,'Submitted')));
    html=['<!doctype html><html><head><meta charset="utf-8"><title>Print student code</title>' ...
        '<style>@page{size:A4;margin:12mm}body{font:10pt Arial,sans-serif;color:#17212b}' ...
        'pre{font:8pt/1.1 Consolas,"Courier New",monospace;white-space:pre-wrap;overflow-wrap:anywhere}' ...
        '@media screen{body{max-width:190mm;margin:18px auto}pre{background:#f4f6f8;padding:12px}}</style>' ...
        '</head><body><p>' details '</p><pre>' escapeHtml(char(solutionCode)) ...
        '</pre><script>window.addEventListener("load",function(){setTimeout(function(){window.print();},300);});</script>' ...
        '</body></html>'];
    f=fopen(outputPath,'w','n','UTF-8');
    if f<0, error('Could not write the temporary print page.'); end
    c=onCleanup(@()fclose(f));
    fwrite(f,html,'char');
    clear c
end

function value=getMetadataField(metadata,name)
    value='';
    if isfield(metadata,name) && ~isempty(metadata.(name))
        value=char(string(metadata.(name)));
    end
end

function out=escapeHtml(in)
    out=char(string(in));
    out=strrep(out,'&','&amp;');
    out=strrep(out,'<','&lt;');
    out=strrep(out,'>','&gt;');
    out=strrep(out,'"','&quot;');
    out=strrep(out,'''','&#39;');
end

function closeReportIfOpen(rpt)
    try
        close(rpt);
    catch
    end
end

function url = solutionPageURL(T,rowIndex,assignment,problemTitle,links)
    url="";
    v=string(T.Properties.VariableNames);
    solutionCol=firstName(v,["Solution ID","SolutionID"]);
    if solutionCol=="", return; end
    solutionID=strtrim(string(T.(solutionCol)(rowIndex)));
    if ismissing(solutionID) || solutionID=="", return; end

    base="";
    [assignmentID,problemID]=problemMapIDs(T,rowIndex,"");
    if assignmentID~="" && problemID~=""
        idKey=problemIDMapKey(assignmentID,problemID);
        if isKey(links,idKey), base=string(links(idKey)); end
    end
    if base==""
        mapKey=char(normalizeKey(string(assignment)+"|"+string(problemTitle)));
        if isKey(links,mapKey)
            base=string(links(mapKey));
        elseif isKey(links,char(normalizeKey(problemTitle)))
            base=string(links(char(normalizeKey(problemTitle))));
        else
            return
        end
    end
    if contains(base,"/solutions/")
        url=base+solutionID;
    else
        url=base+"/solutions/"+solutionID;
    end
end

function [assignmentID,problemID]=problemMapIDs(T,rowIndex,urlCol)
    assignmentID="";
    problemID="";
    vars=string(T.Properties.VariableNames);
    assignmentIDCol=firstName(vars,["Assignment ID","AssignmentID"]);
    problemIDCol=firstName(vars,["Problem ID","ProblemID"]);
    if assignmentIDCol~=""
        assignmentID=leadingNumericID(T.(assignmentIDCol)(rowIndex,:));
    elseif any(vars=="ProblemSetURL")
        assignmentID=leadingNumericID(T.ProblemSetURL(rowIndex,:));
    end
    if problemIDCol~=""
        problemID=leadingNumericID(T.(problemIDCol)(rowIndex,:));
    elseif urlCol~=""
        problemID=leadingNumericID(T.(urlCol)(rowIndex,:));
    elseif any(vars=="ProblemURL")
        problemID=leadingNumericID(T.ProblemURL(rowIndex,:));
    end
end

function id=leadingNumericID(value)
    value=strtrim(string(value));
    id="";
    if ismissing(value) || value=="", return; end
    token=regexp(char(value),'^(\d+)','tokens','once');
    if ~isempty(token), id=string(token{1}); end
end

function key=problemIDMapKey(assignmentID,problemID)
    key=char("assignment"+normalizeKey(assignmentID)+"problem"+normalizeKey(problemID));
end

function base=problemPageBase(T,rowIndex,urlCol)
    base=strtrim(string(T.(urlCol)(rowIndex,:)));
    if ismissing(base) || base=="", return; end
    if startsWith(lower(base),["http://","https://"]), return; end

    vars=string(T.Properties.VariableNames);
    cohortCol=firstName(vars,["CohortURL","CourseURL","Course URL"]);
    if cohortCol=="", return; end
    course=strtrim(string(T.(cohortCol)(rowIndex,:)));
    if ismissing(course) || course=="", return; end
    if ~startsWith(lower(course),["http://","https://"])
        course="https://grader.mathworks.com/courses/"+course;
    end
    if startsWith(base,"/courses/")
        base="https://grader.mathworks.com"+base;
    elseif startsWith(base,"courses/")
        base="https://grader.mathworks.com/"+base;
    elseif startsWith(base,"/problems/")
        base=course+base;
    else
        base=course+"/problems/"+base;
    end
end

function description = studentSummaryText(T,student,assignment)
    v=string(T.Properties.VariableNames);
    nameCol=firstName(v,["Student Name","StudentName","Learner Name"]);
    emailCol=firstName(v,["Student Email","StudentEmail","Email","Email Address"]);
    assignmentCol=firstName(v,["Assignment Title","AssignmentTitle"]);
    problemCol=firstName(v,["Problem Title","ProblemTitle"]);
    mask=false(height(T),1);
    if nameCol~="", mask=mask | string(T.(nameCol))==string(student); end
    if emailCol~="", mask=mask | lower(string(T.(emailCol)))==lower(string(student)); end
    if assignmentCol~="", mask=mask & string(T.(assignmentCol))==string(assignment); end
    studentRows=find(mask);
    name=string(student);
    if ~isempty(studentRows) && nameCol~="", name=string(T.(nameCol)(studentRows(1))); end
    name=chineseToPinyin(name);
    attempted=0;
    if problemCol~="", attempted=numel(unique(string(T.(problemCol)(studentRows)),'stable')); end
    description=sprintf('%s | %d problem(s) with submitted solution rows in this import',name,attempted);
end

function [counts,problemTitles,problemMeans,overallMean,groupText] = summarizeStats(T,G,selectedAssignment,selectedGroups)
    counts=struct('Completed',0,'Enrolled',0,'CompletionRate',NaN);
    problemTitles=strings(0,1); problemMeans=[]; overallMean=NaN; groupText=strings(0,1);
    v=string(T.Properties.VariableNames);
    emailCol=firstName(v,["Student Email","StudentEmail","Email","Email Address"]);
    passCol=firstName(v,["Tests Passed","TestsPassed"]);
    totalCol=firstName(v,["Total Tests","TotalTests"]);
    probCol=firstName(v,["Problem Title","ProblemTitle"]);
    assCol=firstName(v,["Assignment Title","AssignmentTitle"]);
    timeCol=firstName(v,["Submitted Time","SubmittedTime"]);
    if emailCol=="" || passCol=="" || totalCol=="", return; end
    email=lower(strtrim(string(T.(emailCol))));
    passed=double(T.(passCol)); total=double(T.(totalCol));
    if probCol=="", problem=repmat("Problem",height(T),1); else, problem=string(T.(probCol)); end
    if assCol=="", assignment=repmat("Assignment",height(T),1); else, assignment=string(T.(assCol)); end
    if selectedAssignment~="All assignments", mask=assignment==string(selectedAssignment); else, mask=true(height(T),1); end
    if ~any(mask), return; end
    if timeCol=="", submitted=NaT(height(T),1); else, submitted=parseTimes(T.(timeCol)); end
    reportIdx=find(mask);
    keys=unique([email(reportIdx),assignment(reportIdx)],'rows','stable');
    latest=[];
    for k=1:size(keys,1)
        learnerRows=reportIdx(email(reportIdx)==keys(k,1) & assignment(reportIdx)==keys(k,2));
        ps=unique(problem(learnerRows),'stable');
        for p=1:numel(ps)
            candidates=learnerRows(problem(learnerRows)==ps(p));
            if any(~isnat(submitted(candidates)))
                [~,j]=max(submitted(candidates)); latest(end+1)=candidates(j); %#ok<AGROW>
            else
                latest(end+1)=candidates(end); %#ok<AGROW>
            end
        end
    end
    if isempty(latest), return; end
    latestEmail=email(latest); latestProblem=problem(latest); latestAssignment=assignment(latest);
    latestScore=100*passed(latest)./max(total(latest),1);
    selectedLatest=true(numel(latest),1);
    allGroupsSelected=any(selectedGroups=="All groups");
    if ~allGroupsSelected && ~isempty(G) && height(G)>0
        gv=string(G.Properties.VariableNames);
        acctCol=firstName(gv,["Account","ID","SSO","Student ID"]);
        groupCol=firstName(gv,["GROUP","Group"]);
        if acctCol~="" && groupCol~=""
            roster=lower(strtrim(string(G.(acctCol))));
            rosterEmail=extractBefore(roster+"@","@");
            isSelected=ismember(strtrim(string(G.(groupCol))),selectedGroups);
            selectedAccounts=unique([roster(isSelected);rosterEmail(isSelected)],'stable');
            latestAccount=extractBefore(latestEmail+"@","@");
            selectedLatest=ismember(latestAccount,selectedAccounts) | ismember(latestEmail,selectedAccounts);
        end
    end
    problemTitles=unique(latestProblem(selectedLatest),'stable');
    for p=1:numel(problemTitles)
        use=latestProblem==problemTitles(p) & selectedLatest;
        problemMeans(p)=mean(latestScore(use),'omitnan'); %#ok<AGROW>
    end
    studentKeys=unique([latestEmail(selectedLatest),latestAssignment(selectedLatest)],'rows','stable');
    studentTotals=nan(size(studentKeys,1),1);
    for s=1:size(studentKeys,1)
        use=latestEmail==studentKeys(s,1) & latestAssignment==studentKeys(s,2) & selectedLatest;
        assignmentProblemCount=numel(unique(problem(assignment==studentKeys(s,2)),'stable'));
        studentTotals(s)=sum(latestScore(use),'omitnan')/max(assignmentProblemCount,1);
    end
    overallMean=mean(studentTotals,'omitnan');
    if isempty(G) || height(G)==0
        counts.Completed=numel(unique(latestEmail,'stable'));
        counts.Enrolled=counts.Completed;
        counts.CompletionRate=100;
        groupText="Group roster not loaded";
        return
    end
    gv=string(G.Properties.VariableNames);
    accountCol=firstName(gv,["Account","ID","SSO","Student ID"]);
    groupCol=firstName(gv,["GROUP","Group"]);
    if accountCol=="", groupText="Group roster has no Account/ID column"; return; end
    roster=lower(strtrim(string(G.(accountCol))));
    rosterEmail=extractBefore(roster+"@","@");
    completedAccounts=unique(extractBefore(latestEmail+"@","@"),'stable');
    matched=ismember(roster,completedAccounts) | ismember(rosterEmail,completedAccounts);
    if ~allGroupsSelected && groupCol~=""
        inGroup=ismember(strtrim(string(G.(groupCol))),selectedGroups);
    else
        inGroup=true(height(G),1);
    end
    counts.Completed=sum(matched & inGroup);
    counts.Enrolled=sum(inGroup);
    if counts.Enrolled>0, counts.CompletionRate=100*counts.Completed/counts.Enrolled; end
    if groupCol~=""
        groupNames=unique(string(G.(groupCol)),'stable');
        if ~allGroupsSelected, groupNames=selectedGroups; end
        for g=1:numel(groupNames)
            in=string(G.(groupCol))==groupNames(g);
            totalStudents=sum(in);
            done=sum(matched & in);
            if totalStudents>0, groupText(end+1,1)=sprintf('%s %d/%d (%.0f%%)',groupNames(g),done,totalStudents,100*done/totalStudents); end %#ok<AGROW>
        end
    end
end


function averageAttempts = averageSubmissionsToCorrect(T,G,selectedAssignment,selectedGroups)
    averageAttempts=NaN;
    if ~hasRepeatedSubmissions(T), return; end
    vars=string(T.Properties.VariableNames);
    emailCol=firstName(vars,["Student Email","StudentEmail","Email","Email Address"]);
    passCol=firstName(vars,["Tests Passed","TestsPassed"]);
    totalCol=firstName(vars,["Total Tests","TotalTests"]);
    problemCol=firstName(vars,["Problem Title","ProblemTitle"]);
    assignmentCol=firstName(vars,["Assignment Title","AssignmentTitle"]);
    timeCol=firstName(vars,["Submitted Time","SubmittedTime"]);
    if emailCol=="" || passCol=="" || totalCol=="" || problemCol=="", return; end
    email=lower(strtrim(string(T.(emailCol))));
    problem=strtrim(string(T.(problemCol)));
    if assignmentCol=="", assignment=repmat("Assignment",height(T),1); else, assignment=strtrim(string(T.(assignmentCol))); end
    if selectedAssignment~="All assignments", inReport=assignment==string(selectedAssignment); else, inReport=true(height(T),1); end
    if ~any(selectedGroups=="All groups") && ~isempty(G) && height(G)>0
        groupVars=string(G.Properties.VariableNames);
        accountCol=firstName(groupVars,["Account","ID","SSO","Student ID"]);
        groupCol=firstName(groupVars,["GROUP","Group"]);
        if accountCol~="" && groupCol~=""
            selected=ismember(strtrim(string(G.(groupCol))),selectedGroups);
            account=lower(strtrim(string(G.(accountCol)(selected))));
            accountEmail=extractBefore(account+"@","@");
            learnerAccount=extractBefore(email+"@","@");
            selectedAccounts=unique([account;accountEmail],'stable');
            inReport=inReport & (ismember(email,selectedAccounts) | ismember(learnerAccount,selectedAccounts));
        end
    end
    rows=find(inReport & email~="" & problem~="");
    if isempty(rows), return; end
    keys=unique([email(rows),assignment(rows),problem(rows)],'rows','stable');
    passed=double(T.(passCol)); total=double(T.(totalCol));
    if timeCol=="", submitted=NaT(height(T),1); else, submitted=parseTimes(T.(timeCol)); end
    attemptsToCorrect=[];
    for k=1:size(keys,1)
        candidates=rows(email(rows)==keys(k,1) & assignment(rows)==keys(k,2) & problem(rows)==keys(k,3));
        times=submitted(candidates);
        timed=~isnat(times);
        if any(timed)
            timedRows=candidates(timed);
            [~,order]=sort(times(timed));
            candidates=[timedRows(order);candidates(~timed)];
        end
        correct=passed(candidates)>=total(candidates) & total(candidates)>0;
        firstCorrect=find(correct,1);
        if ~isempty(firstCorrect)
            attemptsToCorrect(end+1,1)=firstCorrect; %#ok<AGROW>
        end
    end
    if ~isempty(attemptsToCorrect), averageAttempts=mean(attemptsToCorrect); end
end

function name=firstName(vars,candidates)
    name="";
    for i=1:numel(candidates)
        j=find(strcmpi(strtrim(vars),candidates(i)),1);
        if ~isempty(j), name=vars(j); return; end
    end
end

function tf=reportHasChineseNames(T)
    vars=string(T.Properties.VariableNames);
    nameCol=firstName(vars,["Student Name","StudentName","Learner Name"]);
    tf=false;
    if nameCol=="", return; end
    names=string(T.(nameCol));
    for k=1:numel(names)
        [~,~,~,~,hasHan]=chineseToPinyin(names(k));
        if hasHan
            tf=true;
            return
        end
    end
end

function tf=pinyinLibraryAvailable()
    [~,~,~,tf]=chineseToPinyin("张三");
end

function key=normalizeKey(value)
    key=lower(regexprep(strtrim(string(value)),'[^a-zA-Z0-9]',''));
end

function t=parseTimes(x)
    if isdatetime(x), t=x; return; end
    s=string(x);
    try
        t=datetime(s,'InputFormat','yyyy-MM-dd HH:mm:ss ''UTC''','TimeZone','UTC');
    catch
        try, t=datetime(s,'TimeZone','UTC'); catch, t=NaT(size(s)); end
    end
    t.TimeZone='';
end




