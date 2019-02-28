module sharedfuncs;

import std.stdio;
import std.conv;
import std.regex;
import std.string;
import std.net.curl;


bool IsDayWithinThreeDays(string raw_dat) {

    return IsDayWithinCertainTime(raw_dat, 3);

}

bool IsDayWithinFiveDays(string raw_dat) {

    return IsDayWithinCertainTime(raw_dat, 5);

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

    auto day_posted         = regex(`\d+ days ago`);
    string day_posted_split = matchFirst(raw_dat, day_posted)[0];
    if (!day_posted_split.empty) {

        return to!int(day_posted_split.split(" ")[0]);

    }

    throw new Exception("Day not found");

}

int GetTotalPagesForSearch(string search_html) {

    auto page_count_reg   = regex(`Page \d+ of \d+`);
    string page_count_raw = (matchFirst(search_html, page_count_reg)[0]);
    string[] page_count_split = page_count_raw.split(" ");

    return to!int(page_count_split[page_count_split.length - 1]);

}