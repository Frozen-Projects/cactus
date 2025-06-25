#include <iostream>
#include <string>
#include <vector>
#include <fstream>
#include <cstdlib>
#include <cassert>
#include <cstring>
#include <thread>
#include <chrono>
#include <iomanip>

#include "utils.h"
#include "../../cactus/cactus.h"

// Include nlohmann json for proper JSON handling
#include "../../cactus/json.hpp"
using json = nlohmann::ordered_json;

struct GenerationResult {
    std::string text;
    std::chrono::milliseconds time_to_first_token;
    std::chrono::milliseconds total_time;
    int tokens_generated;
};

GenerationResult generateText(cactus::cactus_context& context, const std::string& prompt, int max_tokens = 100) {
    context.generated_text.clear();
    auto start_time = std::chrono::high_resolution_clock::now();
    
    context.params.prompt = prompt;
    context.params.n_predict = max_tokens;
    
    if (!context.initSampling()) {
        std::cerr << "Failed to initialize sampling" << std::endl;
        return {"", std::chrono::milliseconds(0), std::chrono::milliseconds(0), 0};
    }
    
    context.beginCompletion();
    context.loadPrompt();
    
    bool first_token = true;
    std::chrono::high_resolution_clock::time_point first_token_time;
    int tokens_generated = 0;
    
    while (context.has_next_token && !context.is_interrupted) {
        auto token_output = context.doCompletion();
        if (token_output.tok == -1) break;
        
        if (first_token) {
            first_token_time = std::chrono::high_resolution_clock::now();
            first_token = false;
        }
        tokens_generated++;
    }
    
    auto end_time = std::chrono::high_resolution_clock::now();

    context.endCompletion();
    
    auto total_time = std::chrono::duration_cast<std::chrono::milliseconds>(end_time - start_time);
    auto ttft = first_token ? std::chrono::milliseconds(0) : 
                std::chrono::duration_cast<std::chrono::milliseconds>(first_token_time - start_time);
    
    return {context.generated_text, ttft, total_time, tokens_generated};
}

void demonstrateBasicGeneration(cactus::cactus_context& context) {
    std::cout << "\n=== Basic Text Generation Demo ===" << std::endl;
    
    std::cout << "\n--- Single Turn Generation ---" << std::endl;
    std::vector<std::string> prompts = {
        "The future of artificial intelligence is",
        "Write a short story about a robot who discovers emotions:"
    };
    
    for (const auto& prompt : prompts) {
        std::cout << "\nPrompt: " << prompt << std::endl;
        context.rewind();
        std::cout << "Response: " << generateText(context, prompt, 100).text << std::endl;
        std::cout << std::string(60, '-') << std::endl;
    }
    
    context.rewind();
    
    std::cout << "\n--- Multi-Turn Conversation ---" << std::endl;
    std::vector<std::string> messages = {
        "Hello! How are you?",
        "What can you help me with?",
        "Tell me a fun fact about space"
    };
    
    bool first_message = true;
    for (const auto& message : messages) {
        std::cout << "\nUser: " << message << std::endl;
        
        std::string prompt;
        json msgs = json::array();
        msgs.push_back({{"role", "user"}, {"content", message}});

        if (first_message) {
            prompt = context.getFormattedChat(msgs.dump(), "");
            first_message = false;
        } else {
            std::string user_part = context.getFormattedChat(msgs.dump(), "");
            size_t assistant_start = user_part.find("<|im_start|>assistant");
            if (assistant_start != std::string::npos) {
                prompt = user_part.substr(0, assistant_start) + "<|im_start|>assistant\n";
            } else {
                prompt = user_part;
            }
        }
        
        auto result = generateText(context, prompt, 150);
        
        std::cout << "Bot: " << result.text << std::endl;
        
        std::cout << "(TTFT: " << result.time_to_first_token.count() << "ms, "
                  << "Total: " << result.total_time.count() << "ms, "
                  << "Tokens: " << result.tokens_generated;
        
        if (result.tokens_generated > 0 && result.total_time.count() > 0) {
            float tokens_per_second = (float)result.tokens_generated * 1000.0f / result.total_time.count();
            std::cout << ", Speed: " << std::fixed << std::setprecision(1) << tokens_per_second << " tok/s";
        }
        
        std::cout << ")" << std::endl;
        std::cout << std::string(60, '-') << std::endl;
    }
}

void demonstrateChatMode(cactus::cactus_context& context) {
    std::cout << "\n=== Interactive Chat Demo ===" << std::endl;
    std::cout << "Type 'quit' to exit, 'clear' to reset conversation" << std::endl;
    
    std::string input;
    bool first_message = true;
    
    while (true) {
        std::cout << "\nYou: ";
        std::getline(std::cin, input);
        
        if (input == "quit" || input == "exit") {
            break;
        }
        
        if (input == "clear") {
            context.rewind();
            first_message = true;
            std::cout << "Conversation cleared." << std::endl;
            continue;
        }
        
        if (input.empty()) continue;
        
        std::string prompt;
        json msgs = json::array();
        msgs.push_back({{"role", "user"}, {"content", input}});

        if (first_message) {
            prompt = context.getFormattedChat(msgs.dump(), "");
            first_message = false;
        } else {
            std::string user_part = context.getFormattedChat(msgs.dump(), "");
            size_t assistant_start = user_part.find("<|im_start|>assistant");
            if (assistant_start != std::string::npos) {
                prompt = user_part.substr(0, assistant_start) + "<|im_start|>assistant\n";
            } else {
                prompt = user_part;
            }
        }
        
        auto result = generateText(context, prompt, 200);
        
        auto end_time = std::chrono::high_resolution_clock::now();
        
        std::cout << "Bot: " << result.text << std::endl;
        std::cout << "(TTFT: " << result.time_to_first_token.count() << "ms, "
                  << "Total: " << result.total_time.count() << "ms, "
                  << "Tokens: " << result.tokens_generated;
        
        if (result.tokens_generated > 0 && result.total_time.count() > 0) {
            float tokens_per_second = (float)result.tokens_generated * 1000.0f / result.total_time.count();
            std::cout << ", Speed: " << std::fixed << std::setprecision(1) << tokens_per_second << " tok/s";
        }
        std::cout << ")" << std::endl;
    }
}

void demonstrateSamplingVariations(cactus::cactus_context& context) {
    std::cout << "\n=== Sampling Variations Demo ===" << std::endl;
    
    const std::string prompt = "Write a creative opening line for a science fiction novel:";
    
    struct SamplingConfig {
        std::string name;
        float temperature;
        int top_k;
        float top_p;
        float repeat_penalty;
    };
    
    std::vector<SamplingConfig> configs = {
        {"Conservative", 0.3f, 20, 0.8f, 1.05f},
        {"Balanced", 0.7f, 40, 0.9f, 1.1f},
        {"Creative", 1.0f, 60, 0.95f, 1.15f},
        {"Wild", 1.3f, 80, 0.98f, 1.2f}
    };
    
    for (const auto& config : configs) {
        std::cout << "\n" << config.name << " sampling (temp=" << config.temperature 
                  << ", top_k=" << config.top_k << ", top_p=" << config.top_p << "):" << std::endl;
        
        // Configure sampling parameters
        context.params.sampling.temp = config.temperature;
        context.params.sampling.top_k = config.top_k;
        context.params.sampling.top_p = config.top_p;
        context.params.sampling.penalty_repeat = config.repeat_penalty;
        
        context.rewind();
        auto result = generateText(context, prompt, 80);
        std::cout << "Response: " << result.text << std::endl;
        std::cout << std::string(60, '-') << std::endl;
    }
}

int main(int argc, char **argv) {
    const std::string model_url = "https://huggingface.co/QuantFactory/SmolLM-360M-Instruct-GGUF/resolve/main/SmolLM-360M-Instruct.Q6_K.gguf";
    const std::string model_filename = "SmolLM-360M-Instruct.Q6_K.gguf";
    
    if (!downloadFile(model_url, model_filename, "LLM model")) {
        return 1;
    }
    
    std::cout << "\n=== Cactus LLM Example ===" << std::endl;
    
    try {
        cactus::cactus_context context;
        
        // Configure model parameters
        common_params params;
        params.model.path = model_filename;
        params.n_ctx = 4096;
        params.n_batch = 512;
        params.n_gpu_layers = 99; // Use GPU acceleration
        params.cpuparams.n_threads = std::thread::hardware_concurrency();
        
        // Cache optimization parameters
        params.n_cache_reuse = 256; // Enable cache reuse with 256 token chunks
        params.n_keep = 32;         // Keep first 32 tokens during context shifts
        
        // Default sampling parameters
        params.sampling.temp = 0.7f;
        params.sampling.top_k = 40;
        params.sampling.top_p = 0.9f;
        params.sampling.penalty_repeat = 1.1f;
        
        // Configure stop tokens
        params.antiprompt.push_back("<|im_end|>");
        
        std::cout << "Loading model: " << model_filename << std::endl;
        if (!context.loadModel(params)) {
            std::cerr << "Failed to load model" << std::endl;
            return 1;
        }
        
        std::cout << "Model loaded successfully!" << std::endl;
        std::cout << "Model: " << context.llama_init.model.get() << std::endl;
        std::cout << "Context: " << context.llama_init.context.get() << std::endl;
        
        // Run different demonstrations
        if (argc > 1 && std::string(argv[1]) == "chat") {
            demonstrateChatMode(context);
        } else if (argc > 1 && std::string(argv[1]) == "sampling") {
            demonstrateSamplingVariations(context);
        } else if (argc > 1 && std::string(argv[1]) == "basic") {
            demonstrateBasicGeneration(context);
        } else {
            std::cout << "\nAvailable demos:" << std::endl;
            std::cout << "  ./cactus_llm basic    - Basic and conversational text generation" << std::endl;
            std::cout << "  ./cactus_llm chat     - Interactive chat with KV caching" << std::endl;
            std::cout << "  ./cactus_llm sampling - Different sampling strategies" << std::endl;
            std::cout << "\nFeatures:" << std::endl;
            std::cout << "  - Manual conversation management" << std::endl;
            std::cout << "  - Automatic KV cache optimization" << std::endl;
            std::cout << "  - Low-level control over generation" << std::endl;
            std::cout << "\nRunning basic demo by default...\n" << std::endl;
            
            demonstrateBasicGeneration(context);
        }
        
    } catch (const std::exception& e) {
        std::cerr << "Error: " << e.what() << std::endl;
        return 1;
    }
    
    return 0;
}