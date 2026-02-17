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

        // delete copy constructor to prevent dangling ptr of GLFWwindow (RAII)
        LveWindow(const LveWindow &) = delete;

    private:
        void initWindow();

        const int width, height;
        std::string windowName;
        GLFWwindow *window;
    };
}
