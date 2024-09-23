import:py from mtllm.llms {Ollama}

# glob llm = Ollama(model_name='llama3.1');
glob llm = Ollama(model_name='gemma2');

import:jac from rag {RagEngine}
glob rag_engine:RagEngine = RagEngine();

walker interact {
    has message: str;
    has session_id: str;

    can init_session with `root entry {
         visit [-->](`?Session)(?id == self.session_id) else {
            session_node = here ++> Session(id=self.session_id, chat_history=[], status=1);
            print("Session Node Created");

            visit session_node;
        }
    }
    #   can chat with Session entry {
    #     here.chat_history.append({"role": "user", "content": self.message});
    #     data = rag_engine.get_from_chroma(query=self.message);
    #     response = here.llm_chat(
    #         message=self.message,
    #         chat_history=here.chat_history,
    #         agent_role="You are a conversation agent designed to help users with their queries based on the documents provided",
    #         context=data
    #     );

    #     here.chat_history.append({"role": "assistant", "content": response});

    #     report {"response": response};
    # }
}

node Session {
    has id: str;
    has chat_history: list[dict];
    has status: int = 1;

    can 'Respond to message using chat_history as context and agent_role as the goal of the agent'
    llm_chat(
        message:'current message':str,
        chat_history: 'chat history':list[dict],
        agent_role:'role of the agent responding':str,
        context:'retrieved context from documents':list
    ) -> 'response':str by llm();

    can chat with interact entry {
        self.chat_history.append({"role": "user", "content": here.message});
        response = infer(message=here.message, chat_history=self.chat_history) spawn root;
        print(f"Infer Response: {response}");
        self.chat_history.append({"role": "assistant", "content": response.response});

        report {
            "response": response.response
        };
    }
}



enum ChatType {
    RAG : 'Need to use Retrievable information in specific documents to respond' = "RAG",
    QA : 'Given context is enough for an answer' = "user_qa",
    FEEDBACK : 'Give user a thank based on their feedback on the chatbot or user experience' = "user_feedback"
}

node Router {
    can 'route the query to the appropriate task type'
    classify(message: 'query from the user to be routed':str) -> ChatType by llm(method="Reason", temperature=0.0);
}

node Chat {
    has chat_type: ChatType;
}

walker infer {
    has message: str;
    has chat_history: list[dict];

    can init_router with `root entry {
        print("Infer walker: initializing router.");
        visit [-->](`?Router) else {
            print("Infer walker: creating new Router node.");
            router_node = here ++> Router();
            router_node ++> FDChat();
            router_node ++> RagChat();
            router_node ++> QAChat();
            visit router_node;
        }
    }

    can route with Router entry {
        classification = here.classify(message = self.message);
        print(f"Message classified as {classification}");

        if classification == ChatType.RAG {
            print("Routing to RagChat");
            visit [-->](`?RagChat);
        } elif classification == ChatType.QA {
            print("Routing to QAChat");
            visit [-->](`?QAChat);
        } elif classification == ChatType.FEEDBACK {
            print("Routing to FeedbackChat");
            visit [-->](`?FDChat);  # Directly visit FDChat
        } else {
            print("Unknown classification. Cannot route message.");
        }
    }
}

node FDChat :Chat: {
    has chat_type: ChatType = ChatType.FEEDBACK;

    can respond with infer entry {
        can 'Respond to message using chat_history as context and agent_role as the goal of the agent'
        
        respond_with_llm(   
            message: 'current message': str,
            chat_history: 'chat history': list[dict],
            agent_role: 'role of the agent responding': str
        ) -> 'response': str by llm();
        
        # Debugging statements for tracing
        print("Entered FDChat respond method.");
        
        here.response = respond_with_llm(
            here.message, 
            here.chat_history, 
            "You are a conversation agent designed to give the user praise based on their feedback"
        );
        
        print(f"LLM Response: {here.response}");
    }
}

node RagChat :Chat: {
    has chat_type: ChatType = ChatType.RAG;

    can respond with infer entry {
        can 'Respond to message using chat_history as context and agent_role as the goal of the agent'
        respond_with_llm(   message:'current message':str,
                    chat_history: 'chat history':list[dict],
                    agent_role:'role of the agent responding':str,
                    context:'retirved context from documents':list
                        ) -> 'response':str by llm();
        data = rag_engine.get_from_chroma(query=here.message);
        here.response = respond_with_llm(here.message, here.chat_history, "You are a conversation agent designed to help users with their queries based on the documents provided", data);
        print(f"LLM Response: {here.response}");

    }
}


node QAChat :Chat: {
    has chat_type: ChatType = ChatType.QA;

    can respond with infer entry {
        can 'Respond to message using chat_history as context and agent_role as the goal of the agent'
        respond_with_llm(   message:'current message':str,
            chat_history: 'chat history':list[dict],
            agent_role:'role of the agent responding':str
                ) -> 'response':str by llm();
        here.response = respond_with_llm(here.message, here.chat_history, agent_role="You are a conversation agent designed to help users with their queries");
        # here.response = respond_with_llm(here.message, here.chat_history, agent_role="You are a conversation agent designed to give the user praise based on their feedback");
        print(f"LLM Response: {here.response}");

    }
}

