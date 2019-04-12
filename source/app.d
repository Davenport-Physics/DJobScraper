import std.stdio;
import std.format;
import std.json;
import std.file;
import std.conv;
import std.algorithm;
import std.parallelism;
import std.net.curl;
import core.cpuid;

import d2sqlite3;

import linkedin;
import glassdoor;
import careerbuilder;

import sharedfuncs;
import sharedstructs;

static user_data mydata;
job_boards_gen[] job_boards;

void main() {


    Init();

    try {
        ParseMyDataJson();
        StartScraping();
    } catch (Exception e) {
        writeln(e);
    }

}

void Init() {

    job_boards = [careerbuilder.job_board, glassdoor.job_board];
    InitDBs();
    InitMisc();
    
}

void InitMisc() {

    defaultPoolThreads(coresPerCPU()*2 - 1);
    InitGlassDoorIDs();

}

void InitDBs() {

    auto db = Database("DJSCRAPER.db");
    foreach (job_board; job_boards) {

        db.run(format!"DROP TABLE IF EXISTS %s"(job_board.board));
        db.run(format!"CREATE TABLE %s (raw_html text, job text, percentage real, matched text, job_title text, company_name text, "(job_board.board)~
           "within_three_days int, within_five_days int)");

    }
    db.close();

}

void ParseMyDataJson() {

    if (!exists("mydata.json")) {
        throw new Exception("mydata.json does not exist!");
    }
    string text           = readText("mydata.json");
    JSONValue mydata_json = parseJSON(text);

    SetGenericDataWithJson(mydata.jobs, mydata_json["Job-titles"].array);
    SetGenericDataWithJson(mydata.locations, mydata_json["Locations"].array);
    SetGenericDataWithJson(mydata.keywords, mydata_json["Keywords"].array);
    SetGenericDataWithJson(mydata.required_keywords, mydata_json["RequiredKeywords"].array);
    SetGenericDataWithJson(mydata.companies_to_avoid, mydata_json["AvoidCompanies"].array);
    SetGenericLoginInformation(mydata.linkedin_credentials, "LinkedInInfo", mydata_json);

}

void SetGenericDataWithJson(ref string[] info, JSONValue[] json_array) {

    foreach(segment; json_array) {
        info ~= segment.str;
    }

}

void SetGenericLoginInformation(ref login_credentials creds, string website_info, JSONValue mydata_json) {

    creds.username = mydata_json[website_info]["Username"].str;
    creds.password = mydata_json[website_info]["Password"].str;

}

void StartScraping() {

    foreach (job_board; job_boards) {

        try {
            GenericScrape(job_board, mydata);
        } catch (CurlException e) {
            writeln(e);
        }

    }

}

void StartLinkedInSearch() {

    FindEmailFromLinkedIn("Centerbase", mydata.linkedin_credentials.username, mydata.linkedin_credentials.password);

}




