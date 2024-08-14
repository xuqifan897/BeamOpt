#include "paths.h"
#include "./io_helpers.h"
#include <boost/filesystem.hpp>
#include "helper_string.h"

Paths* Paths::m_pInstance = NULL;
void Paths::Initialize(int argc, const char** argv) {
    // check env vars
    if (m_pInstance == NULL)
        m_pInstance = new Paths;
    if (const char* env_d = std::getenv("DOSECALC_DATA")) {
        m_pInstance->m_data_dir = std::string(env_d);
    } else {
        m_pInstance->m_data_dir = "./data";
    }
    std::string user;
    try {
        user = dcio::get_username();
    } catch (std::runtime_error) {
        user = "unknown";
    }

    char* temp_dir = nullptr;
    if (getCmdLineArgumentString(argc, argv, "temp_dir", &temp_dir)) {
        m_pInstance->m_temp_dir = std::string(temp_dir);
    } else
        m_pInstance->m_temp_dir = "/tmp/dosecalc/"+user;
    
    if (! boost::filesystem::is_directory(m_pInstance->m_temp_dir))
        boost::filesystem::create_directories(m_pInstance->m_temp_dir);
}

Paths* Paths::Instance() {
    if (!m_pInstance) {
        m_pInstance = new Paths;
        m_pInstance->Initialize();
    }
    return m_pInstance;
}

