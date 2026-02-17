//
// Created by Reed Sloan on 2/17/26.
//

#include "first_app.hpp"

namespace lve {
    void FirstApp::run() {
        while (!lveWindow.shouldClose()) {
            // check and process any window level events
            glfwPollEvents();
        }
    }
}