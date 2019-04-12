module glassdoor;

import std.stdio;
import std.conv;
import std.regex;
import std.algorithm;
import std.string;
import std.net.curl;
import std.json;

import d2sqlite3;
import sharedstructs;
import sharedfuncs;

static int[string] glassdoor_ids;
static job_boards_gen job_board = 
{
    ScrapeUrl:&ScrapeJobAndLocationWithKeywords,
    GetCompanyName:&GetCompanyNameGlassdoor,
    GetJobTitle:&GetJobTitleGlassdoor,
    UrlIdentifier:&GetUniqueUrlIdentifierGlassdoor,
    board:"glassdoor"
};

void InitGlassDoorIDs() {

    glassdoor_ids["Dallas,Tx"]         = 1139977;
    glassdoor_ids["Plano,Tx"]          = 1140045;
    glassdoor_ids["Irving,Tx"]         = 1140006;
    glassdoor_ids["Arlington,Tx"]      = 1139951;
    glassdoor_ids["Farmers Branch,Tx"] = 1161548;
    glassdoor_ids["Fort Worth,Tx"]     = 1139993;
    glassdoor_ids["Grapevine,Tx"]      = 1139999;
    glassdoor_ids["Southlake,Tx"]      = 1140065; 

}

string[] ScrapeJobAndLocationWithKeywords(user_data mydata, string location, string job) {

    string search_html      = GetRawGlassdoorPage(job, location);
    int total_page_count    = GetTotalPagesForSearch(search_html);
    return ScrapeAllRelatedPagesGlassdoor(search_html, total_page_count);
}

void WriteAllGlassDoorUrlsToFile(string[] all_urls) {

    File fp = File("links.txt", "w+");
    foreach(link; all_urls) {

        fp.writeln(link);

    }
    fp.close();

}

string GetCompanyNameGlassdoor(string raw_dat) {

    return GetGenericDatFromJSONInHTML(raw_dat, `['"]name['"]:\s*"(.*?)"`);

}

string GetJobTitleGlassdoor(string raw_dat) {

    return GetGenericDatFromJSONInHTML(raw_dat, `['"]jobTitle['"]\s*:\s*"(.*?)"`);

}

string[] ScrapeAllRelatedPagesGlassdoor(string search_html, int total_page_count) {

    string[] all_urls = GetGlassdoorJobs(search_html);
    string link_style = GetAdditionalGlassdoorPagesLinkOnly(search_html);
    string current_html_page = GetAdditionalGlassdoorPages(search_html);

    for (size_t i = 1; i < total_page_count; i++) {

        try {

            current_html_page = to!string(get(link_style ~ "_IP" ~ to!string(i+1) ~ ".htm"));
            all_urls ~= GetGlassdoorJobs(current_html_page);

        } catch (Exception e) {

            writeln("Error finding " ~ link_style ~ "_IP" ~ to!string(i+1) ~ ".htm");
            break;

        }

    }

    return all_urls;
    
}

string GetUniqueUrlIdentifierGlassdoor(string url) {

    return (findSplit(url, "jobListingId=")[2]);

}

string GetRawGlassdoorPage(string job, string location) {

    string url = "https://www.glassdoor.com/Job/jobs.htm?suggestCount="~
                 "0&suggestChosen=false&clickSource=searchBtn&typedKeyword=";

    url ~= job.replace(" ", "+");
    url ~= "&sc.keyword=" ~ job.replace(" ", "+") ~ "&locT=C&locId=" ~ to!string(glassdoor_ids[location]) ~ "&jobType=";

    return to!string(get(url));

}

string GetAdditionalGlassdoorPagesLinkOnly(string search_html) {

    string next_page = findSplit(findSplit(search_html, "<li class='page '><a href=\"/Job/")[2], "\">")[0];
    return "https://www.glassdoor.com/Job/" ~ findSplit(next_page, "_IP")[0];

}

string GetAdditionalGlassdoorPages(string search_html) {

    string next_page = findSplit(findSplit(search_html, "<li class='page '><a href=\"/Job/")[2], "\">")[0];
    return to!string(get("https://www.glassdoor.com/Job/" ~ next_page));

}

string[] GetGlassdorJobUrlJson(string search_html) {

    string jobs = findSplit(findSplit(search_html, "<script type=\"application/ld+json\">")[2], "</script>")[0];
    JSONValue jobs_in_json = parseJSON(jobs);
    string[] job_urls = new string[jobs_in_json["itemListElement"].array.length];

    foreach (idx, job; jobs_in_json["itemListElement"].array) {

        job_urls[idx] = job["url"].str;

    }

    return job_urls;

}

string[] GetGlassdoorJobs(string search_html) {

    string remaining_text = search_html;
    string[] jobs;

    while (canFind(remaining_text, "<a href='/partner/")) {

        auto split = findSplit(findSplit(remaining_text, "<a href='/partner/")[2], "' rel='nofollow'");
        jobs ~= "https://www.glassdoor.com" ~ "/partner/" ~ split[0];
        remaining_text = split[2];

    }
    
    return jobs;

}

