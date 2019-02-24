import std.stdio;
import std.json;
import std.file;
import std.conv;
import std.algorithm;
import linkedin;
import glassdoor;

static user_data mydata;

void main() {

    InitDBs();
    InitMisc();

    try {
        ParseMyDataJson();
        StartScraping();
    } catch (Exception e) {
        writeln("Couldn't find mydata.json");
    }

}

void InitMisc() {

    InitGlassDoorIDs();

}

void InitDBs() {

    InitGlassDoorDB();

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

}

void SetGenericDataWithJson(ref string[] info, JSONValue[] json_array) {

    foreach(segment; json_array) {
        info ~= segment.str;
    }

}

void StartScraping() {

    StartScrapingGlassdoor();

}

void StartScrapingGlassdoor() {

    ScrapeGlassdoor(mydata);

}




