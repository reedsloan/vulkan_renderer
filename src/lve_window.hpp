//
// Created by Reed Sloan on 2/17/26.
//

#pragma once

#define GLFW_INCLUDE_VULKAN
#include <GLFW/glfw3.h>
#include <string>

namespace lve {
    class LveWindow {
    public:
        LveWindow(int w, int h, const std::string &name);

        ~LveWindow();

        // Returns true if the window has been instructed to close
        bool shouldClose() const;

        VkExtent2D getExtent() { return {static_cast<uint32_t>(width), static_cast<uint32_t>(height)}; }

        bool wasWindowResized() { return framebufferResized; }
        void resetWindowResizedFlag() { framebufferResized = false; }

        // delete copy constructor to prevent dangling ptr of GLFWwindow (RAII)
        LveWindow(const LveWindow &) = delete;

        void createWindowSurface(VkInstance instance, VkSurfaceKHR *surface);

    private:
        static void framebufferResizeCallback(GLFWwindow *window, int width, int height);
        void initWindow();

        int width, height;
        bool framebufferResized = false;

        std::string windowName;
        GLFWwindow *window;
    };
}
