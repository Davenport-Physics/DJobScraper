# DJobScraper
A program that attempts to scrape multiple job boards, using data you provide in a json file.

# Dependencies

- d2sqlite3
- dmd 2.084.1 (Note, LDC can compile this program but the application experiences a segfault during runtime)

# Build Procedure

DJobScraper utilizes the dub lib repository and build manager. You'll need to fetch a copy of d2sqlite3 using dub. Furthermore, you may need to edit the directory provided in the dub.json file to point dub at your d2sqlite3 location.

Afterwards, it's a simple `dub build` command.

# mydata.json example file

```
{
    "Job-titles" : [
        "Junior Developer",
        "Entry Level Developer",
        "Web Developer"
    ],
    "Locations" : [
        "Dallas,Tx",
        "Plano,Tx"
    ],
    "Keywords" : [
        "java",
        "git",
        "C++",
        "entry level",
        "angularjs",
        "JQuery",
        "python",
        "C#"
    ],
    "AvoidCompanies" : [
        "ACompany",
        "SomeCompany"
    ],
    "LinkedInInfo" : {
        "Username" : "YourEmail@gmail.com",
        "Password" : "HopefullyAGoodPassword"
    }
}
```

