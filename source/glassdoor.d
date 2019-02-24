module glassdoor;

import std.stdio;
import std.conv;
import std.regex;
import std.algorithm;
import std.string;
import std.net.curl;
import std.json;
import d2sqlite3;

static int[string] glassdoor_ids;

/*

https://www.glassdoor.com/Job/jobs.htm?suggestCount=0&suggestChosen=false&clickSource=searchBtn&typedKeyword=Junior+Developer&sc.keyword=Junior+Developer&locT=C&locId=1140065&jobType=

*/

struct job_posting {

    string url;
    float percentage;
    string matched_text;

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

void InitGlassDoorDB() {

    auto db = Database("DJSCRAPER.db");
    db.run("DROP TABLE IF EXISTS glassdoor");
    db.run("CREATE TABLE glassdoor (job text, percentage real, matched text)");

    db.close();

}

void ScrapeGlassdoor(string job, string location, string[] keywords) {

    string search_html   = GetRawGlassdoorPage(job, location);
    int total_page_count = GetTotalGlassdoorPagesForSearch(search_html);
    string[] all_urls    = ScrapeAllRelatedPagesGlassdoor(search_html, total_page_count);
    WriteAllGlassDoorUrlsToSQLTable(ParseJobURLSForRelevantPostings(all_urls, keywords));
    //WriteAllGlassDoorUrlsToFile(StripAllUrlsOfDuplicates(all_urls));

}

void WriteAllGlassDoorUrlsToFile(string[] all_urls) {

    File fp = File("links.txt", "w+");
    foreach(link; all_urls) {

        fp.writeln(link);

    }
    fp.close();

}

void WriteAllGlassDoorUrlsToSQLTable(job_posting[] all_relevant_postings) {

    auto db = Database("DJSCRAPER.db");
    Statement stmt = db.prepare("INSERT INTO glassdoor (job, percentage, matched) VALUES (:job, :percentage, :matched)");
    foreach(post; all_relevant_postings) {

        stmt.inject(post.url, post.percentage, post.matched_text);

    }
    db.close();

}

job_posting[] ParseJobURLSForRelevantPostings(string[] all_urls, string[] keywords) {


    job_posting[] posts;

    foreach(url; all_urls) {

        string raw_dat = to!string(get(url));
        string words_that_matched = "";
        int total_words_matched = 0;
        foreach(words; keywords) {

            if (canFind(raw_dat, words)) {

                words_that_matched ~= words;
                total_words_matched += 1;

            }

        }
        if (total_words_matched == 0) {
            continue;
        }

        float percentage = BoostPercentageByDayPosted(to!float(total_words_matched) / to!float(keywords.length), raw_dat);
        posts ~= GetJobPosting(url, percentage, words_that_matched);

    }

    return posts;


}

job_posting GetJobPosting(string url, float percentage, string words_that_matched) {

    job_posting post = {url:url, percentage:percentage, matched_text:words_that_matched};
    return post;

}

float BoostPercentageByDayPosted(float percentage, string raw_dat) {

    auto day_posted         = regex(`\d+ days ago`);
    string day_posted_split = matchFirst(raw_dat, day_posted)[0];
    if (!day_posted_split.empty) {

        int day = to!int(day_posted_split.split(" ")[0]);
        if (day < 4) {

            percentage += 10.0f;

        } else {

            percentage -= 10.0f;

        }

    }
    if (percentage < 0.0f) {
        percentage = 0.0f;
    }
    return percentage;

}

string[] ScrapeAllRelatedPagesGlassdoor(string search_html, int total_page_count) {

    string[] all_urls = GetGlassdoorJobs(search_html);
    string link_style = GetAdditionalGlassdoorPagesLinkOnly(search_html);
    string current_html_page = GetAdditionalGlassdoorPages(search_html);

    for (size_t i = 1; i < total_page_count-1; i++) {

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

string[] StripAllUrlsOfDuplicates(string[] all_urls) {

    string[] no_duplicates;
    for (size_t i = 0; i < all_urls.length;i++) {

        if (i % 2 == 0) {
            no_duplicates ~= all_urls[i];
        }

    }
    return no_duplicates;

}

string GetRawGlassdoorPage(string job, string location) {

    string url = "" ~ "https://www.glassdoor.com/Job/jobs.htm?suggestCount=0&suggestChosen=false&clickSource=searchBtn&typedKeyword=";
    url ~= job.replace(" ", "+");
    url ~= "&sc.keyword=" ~ job.replace(" ", "+") ~ "&locT=C&locId=" ~ to!string(glassdoor_ids[location]) ~ "&jobType=";

    return to!string(get(url));

}

string GetAdditionalGlassdoorPagesLinkOnly(string search_html) {

    string next_page = findSplit(findSplit(search_html, "<li class='page '><a href=\"/Job/")[2], "\">")[0];

    auto link_split = findSplit(next_page, "_IP");

    return "https://www.glassdoor.com/Job/" ~ link_split[0];

}

string GetAdditionalGlassdoorPages(string search_html) {

    string next_page = findSplit(findSplit(search_html, "<li class='page '><a href=\"/Job/")[2], "\">")[0];
    return to!string(get("https://www.glassdoor.com/Job/" ~ next_page));

}

int GetTotalGlassdoorPagesForSearch(string search_html) {

    auto page_count_reg   = regex(`Page \d+ of \d+`);
    string page_count_raw = (matchFirst(search_html, page_count_reg)[0]);
    string[] page_count_split = page_count_raw.split(" ");

    return to!int(page_count_split[page_count_split.length - 1]);

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

