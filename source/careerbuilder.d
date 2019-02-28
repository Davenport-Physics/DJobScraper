/*

junior dev dallas,tx

https://www.careerbuilder.com/jobs-junior-dev-in-dallas,tx


page count "Page 1 of 12"

https://www.careerbuilder.com/jobs-junior-dev-in-dallas,tx?page_number=5


job link

<a data-gtm="jrp-job-list|job-title-click|21" data-job-did="JD869X6HFBC1DTT4LRX" data-company-did="" href="/job/JD869X6HFBC1DTT4LRX?ipath=JRG21&amp;keywords=junior+dev&amp;location=dallas%2Ctx&amp;searchid=51daf801-3000-4415-befd-7042c226b6d3%3AAPAb7IQ%2BSoz7mJ4J4lyo6AmeTet9f3ry8w%3D%3D&amp;siteid=cbnsv">Full Stack .NET Developer</a>

which points to

https://www.careerbuilder.com/jobs/JD869X6HFBC1DTT4LRX?ipath=JRG21&amp;keywords=junior+dev&amp;location=dallas%2Ctx&amp;searchid=51daf801-3000-4415-befd-7042c226b6d3%3AAPAb7IQ%2BSoz7mJ4J4lyo6AmeTet9f3ry8w%3D%3D&amp;siteid=cbnsv


Company name

"company_name":"Principium Recruiting"

posted "Posted 3 days ago"

*/

module careerbuilder;

import std.stdio;
import std.conv;
import std.regex;
import std.algorithm;
import std.string;
import std.net.curl;
import std.json;
import std.parallelism;
import core.cpuid;
import d2sqlite3;
import sharedstructs;
import sharedfuncs;


void InitCareerBuilderDB() {

    auto db = Database("DJSCRAPER.db");
    db.run("DROP TABLE IF EXISTS careerbuilder");
    db.run("CREATE TABLE careerbuilder (raw_html text, job text, percentage real, matched text, company_name text, "~
           "within_three_days int, within_five_days int)");

    db.close();

}

void ScrapeCareerBuilder(user_data mydata) {

    string[] all_urls;
    job_posting[] job_posts;
    foreach(job; mydata.jobs) {

        foreach(location; mydata.locations) {

            all_urls ~= ScrapeAllUrlsCareerbuilder(mydata, location, job);

        }

    }
    string[] no_duplicates = StripAllUrlsOfDuplicates(all_urls, &GetUniqueUrlIdentifierCareerbuilder);
    job_posts              = ParseJobURLSForRelevantPostings(no_duplicates, mydata.keywords, &GetCompanyNameCareerbuilder);
    HandleDecreasingAllJobPostsForRelevancyAndSQlWriting(mydata, job_posts, "careerbuilder");

}

string GetUniqueUrlIdentifierCareerbuilder(string url) {

    return findSplit(findSplit(url, "/job/")[2], "?")[0];

}

string GetCompanyNameCareerbuilder(string raw_dat) {

    auto company_name_reg = regex(`['"]company_name['"]:\s*"(.*?)"`);
    string company_name   = matchFirst(raw_dat, company_name_reg)[0];

    if (!company_name.empty) {

        return (company_name.split(":")[1]).replace("\"", "");

    }
    return "";

}

string[] ScrapeAllUrlsCareerbuilder(user_data mydata, string location, string job) {

    string raw_dat  = GetStarterPageCareerBuilder(location, job);
    int total_pages = GetTotalPagesForSearch(raw_dat);

    string[] all_urls   = StripPageOfUrlsCareerbuilder(raw_dat);
    string standard_url = GetCareerBuilderStandardUrl(location, job);

    for (size_t i = 1; i < total_pages; i++) {

        string next_url = standard_url ~ "?page_number=" ~ to!string(i+1);
        all_urls ~= StripPageOfUrlsCareerbuilder(to!string(get(next_url)));

    }
    return all_urls;

}

string GetStarterPageCareerBuilder(string location, string job) {

    return to!string(get(GetCareerBuilderStandardUrl(location, job)));

}

string GetCareerBuilderStandardUrl(string location, string job) {

    string url = "https://www.careerbuilder.com/jobs-"~
             job.replace(" ", "-")~
             "-in-"~
             location;

    return url;

}

string[] StripPageOfUrlsCareerbuilder(string raw_dat) {

    string current_dat = raw_dat;
    string[] all_urls_in_page;
    while (canFind(current_dat, "href=\"/job/")) {

        auto split = findSplit(findSplit(current_dat, "href=\"/job/")[2], "cbnsv\"");
        all_urls_in_page ~= "https://www.careerbuilder.com/jobs/" ~ split[0] ~ "cbnsv";
        current_dat = split[2];

    }
    return all_urls_in_page;

}

