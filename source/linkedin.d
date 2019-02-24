module linkedin;

import std.stdio;
import std.conv;
import std.regex;
import std.algorithm;
import std.string;
import std.net.curl;

static string cookiesFile = "cookies.txt";
static HTTP http;

void FindEmailFromLinkedIn(string company_name, string username, string password) {

    WriteLoginPageToHtml(LoginToLinkedInWithCredentials(username, password));
    FindAllLinkedInPeopleHits(FindLinkedPeopleFromCompanySearch(company_name));

}

string LoginToLinkedInWithCredentials(string username, string password) {

    http = HTTP();
    http.handle.set(CurlOption.cookiefile, cookiesFile);
    http.handle.set(CurlOption.cookiejar , cookiesFile);

    string csrf_token  = GetCSRFTokenFromLinkedIn();
    char[] login_stuff = post("https://www.linkedin.com/uas/login-submit", 
                        ["session_key'" : username, "session_password" : password, "loginCsrfParam" : csrf_token], http);

    return to!string(login_stuff);

}

string GetCSRFTokenFromLinkedIn() {

    string raw_main_page = to!string(get("https://www.linkedin.com", http));
    auto content_before_value = findSplit(raw_main_page, "<input name=\"loginCsrfParam\" id=\"loginCsrfParam-login\" type=\"hidden\" value=\"")[2];

    return findSplit(content_before_value, "\"/>")[0];

}

string FindLinkedPeopleFromCompanySearch(string company) {

    string company_formatted_correctly = "" ~ "https://www.linkedin.com/search/results/people/?keywords=" ~ company.replace(" ", "%20") ~ "&origin=CLUSTER_EXPANSION";
    return to!string(get(company_formatted_correctly, http));

}

void FindAllLinkedInPeopleHits(string company_linked_in) {

    FindPublicIdentifiers(company_linked_in);

}

void WriteLoginPageToHtml(string login_content) {

    File fp = File("login.html", "w+");
    fp.writeln(login_content);
    fp.close();

}

void FindPublicIdentifiers(string company_linked_in) {

    auto pub_identifier_after     = findSplit(company_linked_in, "&quot;publicIdentifier&quot;:&quot;");
    auto public_identifier_before = findSplit(pub_identifier_after[2], "&quot;")[0];
    
    File fp = File("random.dat", "w+");
    fp.writeln(company_linked_in);
    fp.close();

}