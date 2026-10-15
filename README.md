# NegosyoPlan (Flutter)

A mobile app that helps MSME owners in Iloilo (aged 40–60, not tech-savvy) prepare their EMBRACE loan papers with OLEDIPO. It also includes an OLEDIPO staff dashboard.

- The screens match the "NegosyoPlan Screens" design canvas: teal theme `#0A5763`, the NegosyoPlan logo, the Atkinson Hyperlegible font, and large buttons and text.
- The questions follow the OLEDIPO forms in plain words:
  - Annex A, the application form.
  - Annex C, the Certificate of Residency and Business Operation.
  - Annex D, the business plan.
- **Owners type their own financial statements** for every year since the business started. They type the item lines; the app works out the rest with the formulas of the OLEDIPO Excel template (FINANCIAL STATEMENT.xlsx): the totals, Income from operation and Accumulated net income (= Net income), Merchandise inventory (= Ending inventory), Cash beginning and Capital, beginning (= last year's Cash ending and Total capital), and Drawings (= Total − Total assets). It never estimates an item line.
- **Hiligaynon on screen, English on paper.** On first launch the language screen comes right after the splash, before sign up or log in. Every screen shows Hiligaynon by default (English can be picked; Filipino shows English for now). The PDFs, Word forms and Excel file are always English, as OLEDIPO's forms are. Statement and form terms keep the English word in brackets, e.g. "Sales (Benta)", so the owner can match them to the printed form.

> **Status:** this code was written without the Flutter SDK (it could not be downloaded here), so it has **not been compiled or run yet**. Expect a few small fixes on the first `flutter analyze`.

## Run it

You need Flutter 3.22 or newer.

```bash
cd negosyoplan
flutter create . --project-name negosyoplan --platforms=android,ios   # adds platform folders, keeps lib/
flutter pub get
flutter analyze
flutter test
flutter run
```

To try the app quickly:
1. Create an account.
2. On the Resume screen, tap **Fill with a sample business**. You can also do this later under **Settings › Try with a sample business**.

To open the staff dashboard, tap **OLEDIPO staff sign in** on the Welcome screen.

## Screens (same codes as the canvas)

| Canvas | Screen | Route | File |
|---|---|---|---|
| S00 | Splash | `/` | `screens/account_screens.dart` |
| S01 | Welcome | `/welcome` | 〃 |
| A1 · A2 · A3 | Sign up · Verify mobile · Log in (PIN keypad) | `/signup` `/verify` `/login` | 〃 |
| S01b | Resume | `/resume` | 〃 |
| S02 · S03 · S04 | Language · Privacy · Enterprise Passport intro | `/language` `/privacy` `/passport-start` | `screens/onboarding_screens.dart` |
| S05 | Step 1 · About you | `/about` | `screens/interview/steps_1_to_4.dart` |
| S06 | Step 2 · Your business | `/business` | 〃 |
| S07 | Step 3 · What you sell (kind of business) | `/products` | 〃 |
| S09a · b · c | Step 4 · Making your product / Buying your goods / Your service supplies | `/costs/prod` `/costs/resell` `/costs/service` | 〃 |
| S10 | Step 5 · Financial statements by year | `/financials` | `screens/interview/step_5_statements.dart` |
| S10a · b · c | Income statement · Cash flow · Balance sheet (for the chosen year) | `/statement/income` `/statement/cashflow` `/statement/balance` | 〃 |
| S11 | Step 6 · Your workers | `/people` | `screens/interview/steps_6_to_9.dart` |
| S12 | Step 7 · Financial projection (Annex D 5C) | `/projection` | 〃 |
| S13 | Step 8 · Your loan | `/loan` | 〃 |
| S22c | Upload your requirements (PDF), last step before submitting | `/requirements` | 〃 |
| S16 | Check your answers (summary) | `/check` | `screens/review_screens.dart` |
| S17 · S18 · S19 | Missing items · Warnings · Business plan (Annex D) | `/missing` `/warnings` `/plan` | 〃 |
| S20 – S23 | Consent · Documents · PDF preview · Submission tracker | `/consent` `/documents` `/preview` `/tracker` | `screens/document_screens.dart` |
| S24 – S27 | Home · Enterprise Passport · Financial statements · Settings | `/home` `/passport` `/statements` `/settings` | `screens/main_screens.dart` |
| S28 | Negosyo Helper (chatbot) | `/chat` | `screens/chatbot_screen.dart` |
| Admin | OLEDIPO staff dashboard | `/admin` | `admin/` |

The round chat button on the right side of the interview, summary, Home and Statements screens opens the Negosyo Helper.

## How it works

- **`models/app_data.dart`** holds everything the owner types, exactly as typed:
  - `v` for single answers.
  - `g` for tap-to-choose answers.
  - `lists` for list answers (products, materials, workers, loan items).
  - `years` for the three statements of each year.
- **`logic/statements.dart`** lists the lines of the income statement, cash flow and balance sheet, in the order of the OLEDIPO templates, each with a plain-language hint.
- **`state/app_state.dart`** saves to the phone after every change and handles the offline PIN log-in.
  - It lists the statement years from the start date in Step 2 up to last year.
  - The owner can add the next year.
- **`logic/checks.dart`** finds blank answers (the Missing items screen) and things worth a second look (Warnings). For example, it flags a year whose Drawings come out below zero. It points these out and never changes a number.
  - The only sums the app makes are the "Total" lines under lists the owner typed, and the production cost per unit asked for by Annex D 3.3.
- **`services/pdf_service.dart`** makes the PDFs on the phone:
  - Annex D business plan.
  - Annex A application form. Capital, gross sales and net assets are copied from the latest typed statements, and each line says which line it came from.
  - Annex C certificates, ready for the barangay captain to sign.
  - The three statements for every year.
  - The Enterprise Passport.
  - The requirements checklist.
  - Blanks print in red as "[Blank — not filled in]".
- **`services/word_forms.dart`** fills the official OLEDIPO forms (Annex A, C and D) as Word files, in the original layout. The owner saves or sends them from the Documents screen (or the "Word file" button on a preview).
  - The templates are in `assets/templates/`. They are the original forms with fill-in marks added: `{{key}}` (or `{{key|default}}`) for a blank, and `{{#flag}} … {{/flag}}` around a check mark that shows only when the box applies.
  - `DocxFiller` opens the .docx (a zip), writes the answers into `word/document.xml`, and zips it again. No internet, no AI.
  - Lists longer than the form's table (5 products, 7 raw materials, 5 workers) share the last row.
  - Not filled in, on purpose: the barangay captain's name and signing details (Annex C), the loan period, purpose, items list and project cost table (Annex A and D; the LIDEP officer checks loan use after release), and everything for the Secretariat or TWG.
  - **Check first (S22b, `/form`):** tapping Annex A, C or D on the Documents screen opens the form in its template layout with the owner's answers, before anything is saved. `services/form_preview.dart` draws it as a PDF: a picture of each blank template page (`assets/forms/`) with the answers written on the blanks and ticks on the boxes. It uses the same answers as the Word file, so what the owner checks is what they download. Buttons: Print, and "Looks right · Download" (the Word file).
  - To change a template: edit the original form, then rerun `tool/templates/build.py` (adds the marks), `geometry.py` (measures where every blank and box sits and makes the page pictures and `forms_layout.json`), and `fill.py` (fills it with the sample answers so you can check it in Word).
- **`i18n/`**: `tr()` shows on-screen text in the owner's language; `hil.dart` holds the Hiligaynon text, keyed by the English text in the code. Sentences with numbers are matched by patterns in `tr.dart`. Nothing in `services/` (printed documents) uses it.
- **Financial statements on paper** follow the OLEDIPO sample exactly: all years side by side, one statement per page, "P" peso signs, underlined totals, "Certified by" and Proprietor/Proprietress. `logic/statement_layout.dart` holds the rows; the PDF (`pdf_service.dart`) and the Excel file (`statements_xlsx.dart`, with live formulas) both use it. On the Financial statements screen and the statement previews, **Download** lets the owner pick PDF or Excel (both have all three statements). `tool/statements/xlsx_twin.py` is the same Excel writer in Python, for checking the output in LibreOffice.
- **Requirements are uploaded in one place, at the end.** The interview is 8 steps and never asks for files. After checking the answers and making the documents, the owner uploads three requirements as PDF on one screen: business permit (one file), the signed Certificate of Residency and Business Operation / Annex C (one file), and training certificates (one per certificate, as many as they have). Then **Submit to OLEDIPO**.
  - Stored locally only, no server yet: `services/requirement_store.dart` keeps the list in SQLite (`negosyoplan.db`, table `requirement_files`) and copies each PDF into the app's documents folder (`requirements/`). Only real PDFs (file starts with `%PDF`) up to 10 MB are accepted. Adding a new permit or Annex C replaces the old one.
  - "Submit" for now marks the files as sent on the phone. Hook the server upload into `AppState.submitApplication` later.
  - Test mode (`kTestAnswers`) shows "Add test PDFs" so the screen can be tried without real files.
- **`admin/`** is the staff dashboard. It uses sample data only. Sections: Overview, MSME Passports (applications merged in, with side drawers for an application and its requirements), Requirements review, Reports, Staff and roles, and Privacy and audit. Statuses are Pending, Accepted and Returned for completion. Files open in a viewer where staff verify, ask for a new copy, or print them. Every staff action is logged.

## Before real use

- Store data encrypted. `shared_preferences` is not encrypted; use `flutter_secure_storage` plus an encrypted database.
- Replace the simple PIN hash with a salted, slow hash, and limit the number of attempts.
- Add a server for:
  - SMS verification.
  - Consent-based sharing with OLEDIPO.
  - Sync.
  - Staff sign-in with roles.
- Requirements photos: connect `image_picker`. For now, tapping the camera only marks the file as saved.
- Read aloud (`flutter_tts`) and native-speaker Hiligaynon and Filipino text.
- Negosyo Helper: the answers are pre-written. To connect a real assistant, replace `HelperBrain.reply` and keep it limited to the OLEDIPO forms. It must never type or change the owner's answers.
- OLEDIPO sign-off on the Annex A source lines (Capital = Capital, beginning; Annual gross sales = Sales; Business net assets = Total capital).

The app helps owners apply. It never decides or predicts loan approval; the EMBRACE TWG decides.
