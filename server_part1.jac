walker interact {
    can return_message with `root entry {
        report {
            "response": "Hello, world!"
        };
    }
}

walker interact_with_body {
    has name: str;

    can return_message with `root entry {
        report {
            "response": "Hello, " + self.name + "!"
        };
    }
}

walker greet_walker {
    has name: str;
    has my_name: str;
    can return_message with `root entry {
        report {
            "response": "Greetings, " + self.name + "! Welcome to the system." + " My name is " + self.my_name + "."
        };
    }
}

walker calculate_sum {
    has a: int;
    has b: int;
    
    can return_message with `root entry {
        report {
            "response": "The sum of " + str(self.a) + " and " + str(self.b) + " is " + str(self.a + self.b) + "."
        };
    }
}