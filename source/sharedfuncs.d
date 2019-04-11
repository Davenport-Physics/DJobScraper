module sharedfuncs;

import std.stdio;
import std.conv;
import std.regex;
import std.algorithm;
import std.string;
import std.net.curl;
import std.parallelism;

import sharedstructs;
import d2sqlite3;
import sharedstructs;


string[] GetAllUrlsGeneric(user_data mydata, string[] function(user_data, string, string) ScrapeUrlFunc) {

    string[] all_urls;
    foreach(job; mydata.jobs) {

        foreach(location; mydata.locations) {

            all_urls ~= ScrapeUrlFunc(mydata, location, job);
        }

    }
    return all_urls;

}

bool IsDayWithinThreeDays(string raw_dat) {

    return IsDayWithinCertainTime(raw_dat, 3);

}

bool IsDayWithinFiveDays(string raw_dat) {

    return IsDayWithinCertainTime(raw_dat, 5);

}

job_posting[] ParseJobURLSForRelevantPostings(string[] all_urls, user_data mydata, string function(string) GetCompanyName, string function(string) GetJobTitle) {

    job_posting[] posts = new job_posting[all_urls.length];

    foreach(idx, url; taskPool.parallel(all_urls)) {

        string raw_dat = "";
        try{
            raw_dat = to!string(get(url));
        } catch (CurlException e) {
            writeln(e);
        }

        string words_that_matched = "";
        int total_words_matched = 0;

        SetWordsThatMatched(raw_dat, mydata.keywords, words_that_matched, total_words_matched);

        if (total_words_matched == 0) {
            continue;
        }

        float percentage = BoostPercentageByDayPosted(to!float(total_words_matched) / to!float(mydata.keywords.length), raw_dat);
        percentage       = GetPercentageBasedOnRequiredWords(percentage, words_that_matched, mydata.required_keywords);
        posts[idx]       = GetJobPosting(raw_dat, url, percentage, words_that_matched, GetCompanyName, GetJobTitle);

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

float GetPercentageBasedOnRequiredWords(float percentage, string words_that_matched, string[] required_keywords) {

    foreach (keyword; required_keywords) {

        if (!canFind(words_that_matched, keyword)) {

            percentage -= .25;

        }

    }
    return percentage;

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

string[] StripAllUrlsOfDuplicates(string[] all_urls, string function(string) identifier_func) {

    string[] no_duplicates;
    no_duplicates ~= all_urls[0];

    foreach(url; all_urls) {

        bool found = false;
        foreach(no_dup; no_duplicates) {

            string no_dup_split = identifier_func(no_dup);
            string url_split    = identifier_func(url);

            if (no_dup_split == url_split) {
                found = true;
                break;
            }

        }
        if (!found) {
            no_duplicates ~= url;
        }

    }
    return no_duplicates;

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

job_posting GetJobPosting(string raw_dat, string url, float percentage, string words_that_matched, string function(string) GetCompanyName, string function(string) GetJobTitle) {

    job_posting post = {
        raw_html:raw_dat, 
        url:url,
        percentage:percentage, 
        matched_text:words_that_matched,
        company_name:GetCompanyName(raw_dat),
        job_title:GetJobTitle(raw_dat),
        within_three_days:to!int(IsDayWithinThreeDays(raw_dat)),
        within_five_days:to!int(IsDayWithinFiveDays(raw_dat))
    };
    return post;

}

void HandleDecreasingAllJobPostsForRelevancyAndSQlWriting(user_data mydata, job_posting[] job_posts, string table_name) {

    DecreaseRelevancyOfPostings(job_posts, mydata.companies_to_avoid);
    WriteAllGlassDoorUrlsToSQLTable(job_posts, table_name);

}

void WriteAllGlassDoorUrlsToSQLTable(job_posting[] all_relevant_postings, string table_name) {

    auto db = Database("DJSCRAPER.db");
    Statement stmt = db.prepare("INSERT INTO " ~ table_name ~ " (raw_html, job, percentage, matched, job_title, "~
                                "company_name, within_three_days, within_five_days) VALUES "~
                                "(:raw_html, :job, :percentage, :matched, :job_title, :company_name, "~
                                ":within_three_days, :within_five_days)");

    foreach(post; all_relevant_postings) {

        if (post.url.length != 0) {
            stmt.inject(post.raw_html, post.url, 
                        post.percentage, post.matched_text, post.job_title, 
                        post.company_name, post.within_three_days, 
                        post.within_five_days);
        }

    }
    stmt.finalize();
    db.close();

}

bool IsDayWithinCertainTime(string raw_dat, int max_day) {

    int day;
    try { 
        day = GetDayPosted(raw_dat);
    } catch (Exception e) {
        return false;
    }

    if (day <= max_day) {
        return true;
    } else {
        return false;
    }

}

int GetDayPosted(string raw_dat) {

    auto day_posted           = regex(`\d+ days ago`);
    auto hours_posted         = regex(`\d+ hours ago`);
    string day_posted_split   = matchFirst(raw_dat, day_posted)[0];
    string hours_posted_split = matchFirst(raw_dat, hours_posted)[0];
    if (!day_posted_split.empty) {

        return to!int(day_posted_split.split(" ")[0]);

    } else if (!hours_posted_split.empty) {

        int hours = to!int(hours_posted_split.split("")[0]);
        if (hours <= 24) {
            return 1;
        } else {
            return 2;
        }

    }

    throw new Exception("Day not found");

}

int GetTotalPagesForSearch(string search_html) {

    auto page_count_reg   = regex(`Page \d+ of \d+`);
    string page_count_raw = (matchFirst(search_html, page_count_reg)[0]);
    string[] page_count_split = page_count_raw.split(" ");

    return to!int(page_count_split[page_count_split.length - 1]);

}

string GetGenericDatFromJSONInHTML(string raw_dat, string reg) {

    string dat = matchFirst(raw_dat, reg)[0];

    if (!dat.empty) {
        dat = (dat.split(":")[1]).replace("\"", "");
        dat = dat.replace("\'", "");
        return dat;
    }

    return "";

}