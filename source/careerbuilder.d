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

void ScrapeCareerBuilder(user_data mydata) {

    string[] all_urls       = GetAllUrlsGeneric(mydata, &ScrapeAllUrlsCareerbuilder);
    string[] no_duplicates  = StripAllUrlsOfDuplicates(all_urls, &GetUniqueUrlIdentifierCareerbuilder);
    job_posting[] job_posts = ParseJobURLSForRelevantPostings(no_duplicates, mydata, &GetCompanyNameCareerbuilder, &GetJobTitleCareerbuilder);
    HandleDecreasingAllJobPostsForRelevancyAndSQlWriting(mydata, job_posts, "careerbuilder");

}

string GetUniqueUrlIdentifierCareerbuilder(string url) {

    return findSplit(findSplit(url, "/job/")[2], "?")[0];

}

string GetCompanyNameCareerbuilder(string raw_dat) {

    return GetGenericDatFromJSONInHTML(raw_dat, `['"]company_name['"]:\s*"(.*?)"`);

}

string GetJobTitleCareerbuilder(string raw_dat) {

    return GetGenericDatFromJSONInHTML(raw_dat, `['"]title['"]\s*:\s*"(.*?)"`);

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
             location.toLower();

    return url;

}

string[] StripPageOfUrlsCareerbuilder(string raw_dat) {

    string current_dat = raw_dat;
    string[] all_urls_in_page;
    while (canFind(current_dat, "href=\"/job/")) {

        auto split = findSplit(findSplit(current_dat, "href=\"/job/")[2], "cbnsv\"");
        all_urls_in_page ~= "https://www.careerbuilder.com/job/" ~ split[0] ~ "cbnsv";
        current_dat = split[2];

    }
    return all_urls_in_page;

}

