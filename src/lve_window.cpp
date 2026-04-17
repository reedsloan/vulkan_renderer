//
// Created by Reed Sloan on 2/17/26.
//

#include "lve_window.hpp"
#include <stdexcept>

namespace lve {
    LveWindow::LveWindow(int w, int h, const std::string &name) : width(w), height(h), windowName(name) {
        initWindow();
    }

    LveWindow::~LveWindow() {
        // destroy our resources acquired at init
        glfwDestroyWindow(window);
        glfwTerminate();
    }

    bool LveWindow::shouldClose() const {
        return glfwWindowShouldClose(window);
    }

    void LveWindow::createWindowSurface(VkInstance instance, VkSurfaceKHR*surface) {
        if (glfwCreateWindowSurface(instance, window, nullptr, surface) != VK_SUCCESS) {
            throw std::runtime_error("failed to create window surface!");
        }
    }

    void LveWindow::framebufferResizeCallback(GLFWwindow *window, int width, int height) {
        auto lveWindow = reinterpret_cast<LveWindow*>(glfwGetWindowUserPointer(window));
        lveWindow->framebufferResized = true;
        lveWindow->height = height;
        lveWindow->width = width;
    }

    void LveWindow::initWindow() {
         // initialize GLFW library by calling glfwinit
        glfwInit();
        // use the window hint command to tell glfw to not create an opengl context
        glfwWindowHint(GLFW_CLIENT_API, GLFW_NO_API);
        glfwWindowHint(GLFW_RESIZABLE, GLFW_TRUE);

        // use the create window command to initialize our window pointer
        window = glfwCreateWindow(width, height, windowName.c_str(), nullptr, nullptr);
        glfwSetWindowUserPointer(window, this); 
        glfwSetFramebufferSizeCallback(window, framebufferResizeCallback);
    }
}
