import std.stdio;
import linkedin;
import glassdoor;

void main() {

    InitGlassDoorIDs();
    InitGlassDoorDB();
    ScrapeGlassdoor("Junior Developer", "Dallas,Tx", ["java", "C++", "entry level", "angularjs", "Microcontroller"]);

}




