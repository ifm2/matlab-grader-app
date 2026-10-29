function createFakeGraderReviewData(outputFolder)
% createFakeGraderReviewData Create synthetic files for the local demo.
%   createFakeGraderReviewData() writes files to ./sample-data.
%   No real student records or working course URLs are included.
    if nargin < 1 || strlength(string(outputFolder))==0
        outputFolder = fullfile(fileparts(mfilename('fullpath')),'sample-data');
    end
    if ~isfolder(outputFolder), mkdir(outputFolder); end
    names = ["Avery Morgan";"Jordan Patel";"Riley Chen";"Casey Smith";"Taylor Okafor";"Morgan Reed";"Jamie Kim";"Alex Rivera";"Sam Taylor";"Robin Singh";"Drew Ellis";"Cameron Bell"];
    accounts = ["fake1001";"fake1002";"fake1003";"fake1004";"fake1005";"fake1006";"fake1007";"fake1008";"fake1009";"fake1010";"fake1011";"fake1012"];
    group = repelem(["A";"B";"C"],4,1);
    college = ["NORTH";"SOUTH";"EAST";"WEST";"NORTH";"SOUTH";"EAST";"WEST";"NORTH";"SOUTH";"EAST";"WEST"];
    G = table(group,college,accounts,'VariableNames',{'Group','College','Account'});
    writetable(G,fullfile(outputFolder,'FakeStudentGroups.xlsx'));

    problem = ["Vectors";"If Statements";"Bouncing Ball";"Plotting Results"];
    assignment = repmat("Sample Lab 1",numel(names)*numel(problem),1);
    studentNames = strings(numel(assignment),1); studentEmails=studentNames;
    problemTitle=studentNames; solutionID=studentNames; testsPassed=zeros(numel(assignment),1);
    totalTests=repmat(5,numel(assignment),1); submittedTime=NaT(numel(assignment),1);
    for s=1:numel(names)
        for p=1:numel(problem)
            k=(s-1)*numel(problem)+p;
            studentNames(k)=names(s);
            studentEmails(k)=accounts(s)+"@example.invalid";
            problemTitle(k)=problem(p);
            solutionID(k)=string(91000000+k);
            testsPassed(k)=mod(s*3+p,6);
            if mod(s+p,4)==0, testsPassed(k)=5; end
            submittedTime(k)=datetime(2026,10,12+mod(s,8),9+mod(p*2,9),mod(s*7+p*11,60),0,'TimeZone','UTC');
        end
    end
    T=table(studentNames,studentEmails,solutionID,testsPassed,totalTests,submittedTime,problemTitle,assignment, ...
        'VariableNames',{'Student Name','Student Email','Solution ID','Tests Passed','Total Tests','Submitted Time','Problem Title','Assignment Title'});
    T.('Submitted Time').TimeZone='';
    writetable(T,fullfile(outputFolder,'FakeGraderReport.xlsx'));
    fakeURL=["https://grader.example.invalid/courses/demo/problems/vectors"; ...
        "https://grader.example.invalid/courses/demo/problems/if-statements"; ...
        "https://grader.example.invalid/courses/demo/problems/bouncing-ball"; ...
        "https://grader.example.invalid/courses/demo/problems/plotting-results"];
    L=table(problem,fakeURL,'VariableNames',{'ProblemTitle','ProblemURL'});
    writetable(L,fullfile(outputFolder,'FakeProblemLinks.xlsx'));
end
