//
// Created by Reed Sloan on 2/17/26.
//

#include "lve_window.hpp"

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

    void LveWindow::initWindow() {
         // initialize GLFW library by calling glfwinit
        glfwInit();
        // use the window hint command to tell glfw to not create an opengl context
        glfwWindowHint(GLFW_CLIENT_API, GLFW_NO_API);
        // use another hint to disable our window from being resized after creation
        // (we need to handle this a special way, covered around tutorial 10)
        glfwWindowHint(GLFW_RESIZABLE, GLFW_FALSE);

        // use the create window command to initialize our window pointer
        window = glfwCreateWindow(width, height, windowName.c_str(), nullptr, nullptr);
    }
}
