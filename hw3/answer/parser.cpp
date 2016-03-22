#include <stdio.h>
#include <string>
#include <iostream>
#include <fstream>

using namespace std;

struct Person{
		string name;
		int age;
		int sin;
		string address;
};

int main(){
	// ifstream fileobj ;
	// fileobj.open ("decaf-ast.y");
	// if (!fileobj.good()){ return 1; }

	// string line;

	// while (!fileobj.eof()){
	// 	getline(fileobj, line);
	// 	cout << line << "T\n";
	// }

		Person	diana;
		diana.name="Diana Colos";
		diana.age = 19;
		diana.sin=9999999;
		diana.address = "Romania";

		Person* temp_person;
		temp_person	= &diana;
		temp_person	-> name = "MEMEME";

		cout << diana.name << endl;





	// fileobj.close();
}