module sharedstructs;

struct login_credentials {

    string username;
    string password;

}

struct user_data {

    string[] jobs;
    string[] locations;
    string[] keywords;
    string[] required_keywords;
    string[] companies_to_avoid;
    login_credentials linkedin_credentials;

}

struct job_posting {

    string raw_html;
    string url;
    float percentage;
    string matched_text;
    string company_name;
    string job_title;
    int within_three_days;
    int within_five_days;

};

struct job_boards_gen {

    string[] function(user_data, string, string) ScrapeUrl;
    string function(string) GetCompanyName;
    string function(string) GetJobTitle;
    string function(string) UrlIdentifier;
    string board;

}