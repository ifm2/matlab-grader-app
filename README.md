# MATLAB Grader Review

MATLAB Grader Review is a local MATLAB app for educators who need to make sense of large assessment exports and quickly review individual submissions. It combines MATLAB Grader results with a local student-group roster, so teaching staff can focus on the students and problems they need to discuss.

The project is an early, educator-focused prototype. It is designed to run on your computer with files you choose; it does not send student records to a separate service.

## What it does

- Summarises submissions into one row per student, with compact problem scores and overall results.
- Filters by one or more teaching groups using a separate local roster.
- Displays Chinese student names in Pinyin, with an optional table column for the original characters.
- Shows assignment and problem averages, completion rates, and submission activity.
- Previews the latest submitted MATLAB code and can open its MATLAB Grader solution page in your default browser.
- Creates a one-page A4 student review PDF and provides a print-ready code view for in-person feedback.
- Accepts MATLAB Grader Excel or CSV reports, including **All solutions** exports when attempt history is useful.

The PDF includes the learner's submitted code, submission time, name, group, assignment, problem, and score. Correct/reference solutions are not included yet.

## Get started

1. Clone or download this repository.
2. Open `matlab.toml` in MATLAB R2026b or later to open the project. In earlier MATLAB versions, set the Current Folder to the project directory.
3. Run:

   ```matlab
   GraderReviewApp
   ```

The MATLAB project includes a **Launch Grader Review** shortcut. The Project tab also provides dependency analysis and Git source control for this repository. MATLAB UI components and MATLAB Report Generator are MATLAB product requirements rather than installable package dependencies.

4. Choose **Load sample data** to explore the app with fabricated records, or import your own files.

The sample names and accounts are invented, and the example solution links use the reserved `.invalid` domain.

## Prepare your files

### MATLAB Grader report

Download an Excel or CSV report from MATLAB Grader. The app recognises learner name and email, test results, submission time, problem and assignment titles, solution ID, and—when present—the submitted solution code. The **All solutions** report is needed for attempt counts and the average number of submissions before a correct solution.

### Student groups

Import a separate Excel or CSV roster. It should contain an account identifier (`Account`, `ID`, or `SSO`) that matches the email address or its prefix in the Grader report. Add `Group` and optionally `College` columns to enable group filtering and display.

### Problem URLs (optional)

To open a submission in MATLAB Grader, import a local URL map. The most reliable format has `AssignmentID`, `ProblemID`, and `ProblemURL` columns; `ProblemTitle` is optional. `ProblemURL` can be a full problem-page URL, or a problem URL slug together with a `CohortURL` column. The app matches the IDs in the Grader export, then appends that row's `Solution ID` to open the exact submission. This avoids title spelling differences.

The existing `URL_database.xlsx` format is also supported: `SheetName`, `ProblemSetURL`, `ProblemTitle`, `ProblemURL`, and `CohortURL`. The app extracts assignment and problem IDs from the numeric prefixes in `ProblemSetURL` and `ProblemURL`. Older maps with `ProblemTitle` and `ProblemURL` still work as a fallback; add `Assignment` or `SheetName` when titles repeat between assignments.

## Review workflow

Choose the assignment and one or more groups, then select a problem score to inspect the learner's latest submitted code. Use **Open in browser** to view the submission in MATLAB Grader, **Print code** for a quick print dialog, or **Generate Report** to save a PDF for a student meeting.

The app distinguishes the mean score across problems a student submitted from the overall score across the assignment. Unsubmitted problems do not affect **Avg submitted %**; they count as zero in **Total %**. The active-time estimate sums gaps of up to one hour between submissions.

## Privacy and local files

Student reports, group rosters, solution code, and generated review PDFs can contain personal or sensitive information. Keep them local and review the files you select before sharing or committing anything. The `.gitignore` excludes the local `real-data/` folder and generated review PDFs. The repository contains only fabricated sample records.

The current working copy also has a temporary developer-only real-data shortcut. It expects local files under `real-data/`; other educators should use the import buttons with their own exports. Do not add that folder to a public commit.

## Requirements and limitations

- MATLAB with App Designer UI components (`uifigure`, `uitable`, and related functions).
- MATLAB Report Generator for **Generate Report** PDF output.
- A local group roster and (optionally) a problem URL map; MATLAB Grader does not receive the local group information.
- Optional Python `pypinyin` package for offline display of Chinese student names in Pinyin. The source name is retained internally for matching.

To enable Pinyin display, install `requirements-pinyin.txt` into the same Python environment MATLAB uses. In MATLAB, check the interpreter with `pyenv`, then run `python -m pip install --user -r requirements-pinyin.txt` from that environment. Names are converted locally and are not sent to an external API. If the package is unavailable, the app keeps the original name and shows a status message.

- The prototype does not scrape authenticated MATLAB Grader pages or use a documented instructor API.
- Reference solutions are not imported yet. MathWorks documents that the instructor MATLAB code-files ZIP contains reference solutions and learner code for each assessment item; a future version could import that ZIP and match reference files to assessment items. See [Download submissions to analyze learning outcomes](https://www.mathworks.com/help/matlabgrader/ug/download-submissions-to-analyze-learning-outcomes.html).

This app is a review aid, not a replacement for checking results in MATLAB Grader or your institution's student-record systems.

