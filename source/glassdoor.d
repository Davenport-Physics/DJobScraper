module glassdoor;

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

static int[string] glassdoor_ids;

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
    db.run("CREATE TABLE glassdoor (raw_html text, job text, percentage real, matched text, company_name text, "~
           "within_three_days int, within_five_days int)");

    db.close();

}

void ScrapeGlassdoor(user_data mydata) {

    string[] all_urls;
    job_posting[] job_posts;
    foreach(job; mydata.jobs) {

        foreach(location; mydata.locations) {

            all_urls ~= ScrapeJobAndLocationWithKeywords(mydata, location, job);

        }

    }
    job_posts = ParseJobURLSForRelevantPostings(StripAllUrlsOfDuplicates(all_urls), mydata.keywords);
    HandleDecreasingAllJobPostsForRelevancyAndSQlWriting(mydata, job_posts);

}

string[] ScrapeJobAndLocationWithKeywords(user_data mydata, string location, string job) {

    string search_html      = GetRawGlassdoorPage(job, location);
    int total_page_count    = GetTotalPagesForSearch(search_html);
    return ScrapeAllRelatedPagesGlassdoor(search_html, total_page_count);
}

void HandleDecreasingAllJobPostsForRelevancyAndSQlWriting(user_data mydata, job_posting[] job_posts) {

    DecreaseRelevancyOfPostings(job_posts, mydata.companies_to_avoid);
    WriteAllGlassDoorUrlsToSQLTable(job_posts);

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
    Statement stmt = db.prepare("INSERT INTO glassdoor (raw_html, job, percentage, matched, "~
                                "company_name, within_three_days, within_five_days) VALUES "~
                                "(:raw_html, :job, :percentage, :matched, :company_name, "~
                                ":within_three_days, :within_five_days)");

    foreach(post; all_relevant_postings) {

        if (post.url.length != 0) {
            stmt.inject(post.raw_html, post.url, 
                        post.percentage, post.matched_text, 
                        post.company_name, post.within_three_days, 
                        post.within_five_days);
        }

    }
    stmt.finalize();
    db.close();

}

void DecreaseRelevancyOfPostings(ref job_posting[] job_posts, string[] companies_to_avoid) {

    foreach (ref post; job_posts) {

        foreach (company; companies_to_avoid) {

            if (canFind(post.raw_html, company)) {

                post.percentage -= 0.25f;
                break;

            }

        }

    }

}

job_posting[] ParseJobURLSForRelevantPostings(string[] all_urls, string[] keywords) {


    job_posting[] posts = new job_posting[all_urls.length];

    defaultPoolThreads(coresPerCPU()*2 - 1);
    foreach(idx, url; taskPool.parallel(all_urls)) {

        string raw_dat = "";
        try{
            raw_dat = to!string(get(url));
        } catch (CurlException e) {
            writeln(e);
        }

        string words_that_matched = "";
        int total_words_matched = 0;

        SetWordsThatMatched(raw_dat, keywords, words_that_matched, total_words_matched);

        if (total_words_matched == 0) {
            continue;
        }

        float percentage = BoostPercentageByDayPosted(to!float(total_words_matched) / to!float(keywords.length), raw_dat);
        posts[idx] = GetJobPosting(raw_dat, url, percentage, words_that_matched);

    }

    return posts;


}

void SetWordsThatMatched(string raw_dat, string[] keywords, ref string words_that_matched, ref int total_words_matched) {

    foreach(words; keywords) {

        if (canFind(raw_dat, words)) {

            words_that_matched  ~= words ~ " ";
            total_words_matched += 1;

        }

    }

}

job_posting GetJobPosting(string raw_dat, string url, float percentage, string words_that_matched) {

    job_posting post = {
        raw_html:raw_dat, 
        url:url,
        percentage:percentage, 
        matched_text:words_that_matched,
        company_name:GetCompanyNameGlassdoor(raw_dat),
        within_three_days:to!int(IsDayWithinThreeDays(raw_dat)),
        within_five_days:to!int(IsDayWithinFiveDays(raw_dat))
    };
    return post;

}

float BoostPercentageByDayPosted(float percentage, string raw_dat) {

    if (IsDayWithinThreeDays(raw_dat)) {
        percentage += .1f;
    } else if (IsDayWithinFiveDays(raw_dat)) {
        percentage += .05;
    } else {
        percentage -= .1f;
    }

    if (percentage < 0.0f) {
        percentage = 0.0f;
    }
    return percentage;

}

string GetCompanyNameGlassdoor(string raw_dat) {

    auto company_names_reg = regex(`['"]name['"]:\s*"(.*?)"`);
    string company_name = matchFirst(raw_dat, company_names_reg)[0];

    if (!company_name.empty) {

        return (company_name.split(":")[1]).replace("\"", "");

    }

    return "";

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

string[] StripAllUrlsOfDuplicates(string[] all_urls) {

    string[] no_duplicates;
    no_duplicates ~= all_urls[0];
    auto url_id = regex(`jobListingId=\d+`);

    foreach (url; all_urls) {

        bool found = false;
        foreach (no_dups; no_duplicates) {

            auto dup_match = (findSplit(no_dups, "jobListingId=")[2]);
            auto url_match = (findSplit(url, "jobListingId=")[2]);
            if (url_match == dup_match){
                found = true;
            }

        }
        if (!found) {
            no_duplicates ~= url;
        }

    }

    return no_duplicates;

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

    auto link_split = findSplit(next_page, "_IP");

    return "https://www.glassdoor.com/Job/" ~ link_split[0];

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

