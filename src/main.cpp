// 1. Standard C++ Libraries
#include <cstdlib>
#include <iostream>
#include <stdexcept>
#include <vector>

// 2. Third-Party Libraries
#include <vulkan/vulkan.h>
#define GLFW_INCLUDE_VULKAN // This specific define MUST stay before glfw3.h
#include <GLFW/glfw3.h>

// 3. Your Local Headers (The code you wrote)
#include "first_app.hpp"

// --------------------------------------------------------------------------- //
// Configuration
// --------------------------------------------------------------------------- //
constexpr int WINDOW_WIDTH = 1280;
constexpr int WINDOW_HEIGHT = 720;
constexpr const char *APP_NAME = "Vulkan Renderer";

static const std::vector<const char *> kValidationLayers = {
    "VK_LAYER_KHRONOS_validation"
};

// Resolved at runtime: compiled-in preference + actual layer availability
static bool gValidationEnabled = false;

// --------------------------------------------------------------------------- //
// Debug messenger callback
// --------------------------------------------------------------------------- //
static VKAPI_ATTR VkBool32 VKAPI_CALL debugCallback(
    VkDebugUtilsMessageSeverityFlagBitsEXT messageSeverity,
    VkDebugUtilsMessageTypeFlagsEXT messageType,
    const VkDebugUtilsMessengerCallbackDataEXT *pCallbackData,
    void * /*pUserData*/) {
    (void) messageType;

    if (messageSeverity >= VK_DEBUG_UTILS_MESSAGE_SEVERITY_WARNING_BIT_EXT) {
        std::cerr << "[Vulkan Validation] " << pCallbackData->pMessage << "\n";
    }
    return VK_FALSE;
}

// --------------------------------------------------------------------------- //
// Helpers
// --------------------------------------------------------------------------- //
static bool checkValidationLayerSupport() {
    uint32_t layerCount = 0;
    vkEnumerateInstanceLayerProperties(&layerCount, nullptr);

    std::vector<VkLayerProperties> available(layerCount);
    vkEnumerateInstanceLayerProperties(&layerCount, available.data());

    for (const char *name: kValidationLayers) {
        bool found = false;
        for (const auto &props: available) {
            if (std::strcmp(name, props.layerName) == 0) {
                found = true;
                break;
            }
        }
        if (!found) return false;
    }
    return true;
}

static std::vector<const char *> getRequiredExtensions() {
    uint32_t glfwExtCount = 0;
    const char **glfwExts = glfwGetRequiredInstanceExtensions(&glfwExtCount);

    std::vector<const char *> extensions(glfwExts, glfwExts + glfwExtCount);

    // MoltenVK portability
    extensions.push_back(VK_KHR_PORTABILITY_ENUMERATION_EXTENSION_NAME);

    if (gValidationEnabled) {
        extensions.push_back(VK_EXT_DEBUG_UTILS_EXTENSION_NAME);
    }

    return extensions;
}

static VkResult createDebugUtilsMessenger(
    VkInstance instance,
    const VkDebugUtilsMessengerCreateInfoEXT *pCreateInfo,
    const VkAllocationCallbacks *pAllocator,
    VkDebugUtilsMessengerEXT *pMessenger) {
    auto func = reinterpret_cast<PFN_vkCreateDebugUtilsMessengerEXT>(
        vkGetInstanceProcAddr(instance, "vkCreateDebugUtilsMessengerEXT"));
    return func ? func(instance, pCreateInfo, pAllocator, pMessenger) : VK_ERROR_EXTENSION_NOT_PRESENT;
}

static void destroyDebugUtilsMessenger(
    VkInstance instance,
    VkDebugUtilsMessengerEXT messenger,
    const VkAllocationCallbacks *pAllocator) {
    auto func = reinterpret_cast<PFN_vkDestroyDebugUtilsMessengerEXT>(
        vkGetInstanceProcAddr(instance, "vkDestroyDebugUtilsMessengerEXT"));
    if (func) func(instance, messenger, pAllocator);
}

// --------------------------------------------------------------------------- //
// Application
// --------------------------------------------------------------------------- //
class VulkanApp {
public:
    void run() {
        initWindow();
        initVulkan();
        mainLoop();
        cleanup();
    }

private:
    GLFWwindow *window_ = nullptr;
    VkInstance instance_ = VK_NULL_HANDLE;
    VkDebugUtilsMessengerEXT debugMessenger_ = VK_NULL_HANDLE;

    // ----------------------------------------------------------------------- //
    // Window
    // ----------------------------------------------------------------------- //
    void initWindow() {
        if (!glfwInit()) {
            throw std::runtime_error("Failed to initialise GLFW");
        }

        glfwWindowHint(GLFW_CLIENT_API, GLFW_NO_API); // no OpenGL context
        glfwWindowHint(GLFW_RESIZABLE, GLFW_FALSE); // handle resize later

        window_ = glfwCreateWindow(WINDOW_WIDTH, WINDOW_HEIGHT, APP_NAME, nullptr, nullptr);
        if (!window_) {
            throw std::runtime_error("Failed to create GLFW window");
        }
    }

    // ----------------------------------------------------------------------- //
    // Vulkan init
    // ----------------------------------------------------------------------- //
    void initVulkan() {
        createInstance();
        setupDebugMessenger();

        // ── Next steps (you implement these): ──
        // createSurface();
        // pickPhysicalDevice();
        // createLogicalDevice();
        // createSwapChain();
        // createImageViews();
        // createRenderPass();
        // createGraphicsPipeline();
        // createFramebuffers();
        // createCommandPool();
        // createCommandBuffers();
        // createSyncObjects();
    }

    void createInstance() {
        // Resolve validation: only enable if both compiled-in AND layers present
#ifdef ENABLE_VALIDATION_LAYERS
        if (checkValidationLayerSupport()) {
            gValidationEnabled = true;
            std::cout << "[Info] Validation layers enabled.\n";
        } else {
            gValidationEnabled = false;
            std::cerr << "[Warn] Validation layers requested but not available. "
                    "Continuing without validation.\n"
                    "       Install them: brew install vulkan-validationlayers\n"
                    "       Then set:     export VK_LAYER_PATH=\"$(brew --prefix)/share/vulkan/explicit_layer.d\"\n";
        }
#else
        gValidationEnabled = false;
#endif

        VkApplicationInfo appInfo{};
        appInfo.sType = VK_STRUCTURE_TYPE_APPLICATION_INFO;
        appInfo.pApplicationName = APP_NAME;
        appInfo.applicationVersion = VK_MAKE_VERSION(0, 1, 0);
        appInfo.pEngineName = "No Engine";
        appInfo.engineVersion = VK_MAKE_VERSION(0, 0, 0);
        appInfo.apiVersion = VK_API_VERSION_1_3;

        auto extensions = getRequiredExtensions();

        VkInstanceCreateInfo createInfo{};
        createInfo.sType = VK_STRUCTURE_TYPE_INSTANCE_CREATE_INFO;
        createInfo.pApplicationInfo = &appInfo;
        createInfo.enabledExtensionCount = static_cast<uint32_t>(extensions.size());
        createInfo.ppEnabledExtensionNames = extensions.data();
        createInfo.flags |= VK_INSTANCE_CREATE_ENUMERATE_PORTABILITY_BIT_KHR;

        // Debug messenger for instance creation/destruction
        VkDebugUtilsMessengerCreateInfoEXT debugCreateInfo{};

        if (gValidationEnabled) {
            createInfo.enabledLayerCount = static_cast<uint32_t>(kValidationLayers.size());
            createInfo.ppEnabledLayerNames = kValidationLayers.data();

            populateDebugMessengerCreateInfo(debugCreateInfo);
            createInfo.pNext = &debugCreateInfo;
        } else {
            createInfo.enabledLayerCount = 0;
            createInfo.pNext = nullptr;
        }

        if (vkCreateInstance(&createInfo, nullptr, &instance_) != VK_SUCCESS) {
            throw std::runtime_error("Failed to create Vulkan instance");
        }

        std::cout << "[Info] Vulkan instance created successfully.\n";
    }

    // ----------------------------------------------------------------------- //
    // Debug messenger
    // ----------------------------------------------------------------------- //
    static void populateDebugMessengerCreateInfo(VkDebugUtilsMessengerCreateInfoEXT &info) {
        info = {};
        info.sType = VK_STRUCTURE_TYPE_DEBUG_UTILS_MESSENGER_CREATE_INFO_EXT;
        info.messageSeverity = VK_DEBUG_UTILS_MESSAGE_SEVERITY_VERBOSE_BIT_EXT
                               | VK_DEBUG_UTILS_MESSAGE_SEVERITY_WARNING_BIT_EXT
                               | VK_DEBUG_UTILS_MESSAGE_SEVERITY_ERROR_BIT_EXT;
        info.messageType = VK_DEBUG_UTILS_MESSAGE_TYPE_GENERAL_BIT_EXT
                           | VK_DEBUG_UTILS_MESSAGE_TYPE_VALIDATION_BIT_EXT
                           | VK_DEBUG_UTILS_MESSAGE_TYPE_PERFORMANCE_BIT_EXT;
        info.pfnUserCallback = debugCallback;
    }

    void setupDebugMessenger() {
        if (!gValidationEnabled) return;

        VkDebugUtilsMessengerCreateInfoEXT createInfo{};
        populateDebugMessengerCreateInfo(createInfo);

        if (createDebugUtilsMessenger(instance_, &createInfo, nullptr, &debugMessenger_) != VK_SUCCESS) {
            throw std::runtime_error("Failed to set up debug messenger");
        }
    }

    // ----------------------------------------------------------------------- //
    // Main loop
    // ----------------------------------------------------------------------- //
    void mainLoop() {
        std::cout << "[Info] Entering main loop. Close the window to exit.\n";
        while (!glfwWindowShouldClose(window_)) {
            glfwPollEvents();
        }
    }

    // ----------------------------------------------------------------------- //
    // Cleanup
    // ----------------------------------------------------------------------- //
    void cleanup() {
        if (gValidationEnabled) {
            destroyDebugUtilsMessenger(instance_, debugMessenger_, nullptr);
        }

        vkDestroyInstance(instance_, nullptr);
        glfwDestroyWindow(window_);
        glfwTerminate();

        std::cout << "[Info] Cleaned up successfully.\n";
    }
};

// --------------------------------------------------------------------------- //
// Entry point
// --------------------------------------------------------------------------- //
int main() {
    try {
        lve::FirstApp app;
        app.run();
    } catch (const std::exception &e) {
        std::cerr << "[Fatal] " << e.what() << "\n";
        return EXIT_FAILURE;
    }

    return EXIT_SUCCESS;
}
