module sharedstructs;

struct login_credentials {

    string username;
    string password;

}

struct user_data {

    string[] jobs;
    string[] locations;
    string[] keywords;
    string[] companies_to_avoid;
    login_credentials linkedin_credentials;

}