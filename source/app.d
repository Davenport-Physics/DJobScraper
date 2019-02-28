import std.stdio;
import std.json;
import std.file;
import std.conv;
import std.algorithm;
import std.parallelism;
import std.net.curl;
import core.cpuid;

import linkedin;
import glassdoor;
import careerbuilder;

import sharedstructs;

static user_data mydata;

void main() {

    InitDBs();
    InitMisc();

    try {
        ParseMyDataJson();
        StartScraping();
    } catch (Exception e) {
        writeln(e);
    }

}

void InitMisc() {

    defaultPoolThreads(coresPerCPU()*2 - 1);
    InitGlassDoorIDs();

}

void InitDBs() {

    InitGlassDoorDB();
    InitCareerBuilderDB();

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

    StartScrapingGlassdoor();
    StartScrapingCareerbuilder();

}

void StartScrapingGlassdoor() {

    try {
        ScrapeGlassdoor(mydata);
    } catch (CurlException e) {
        writeln(e);
    }

}

void StartScrapingCareerbuilder() {

    try {
        ScrapeCareerBuilder(mydata);
    } catch (CurlException e) {
        writeln(e);
    }

}




