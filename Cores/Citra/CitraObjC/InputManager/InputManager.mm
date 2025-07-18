//
//  InputManager.mm
//  Folium-iOS
//
//  Created by Jarrod Norwell on 25/7/2024.
//

#include "InputManager.h"

#import <CoreMotion/CoreMotion.h>

#ifdef __cplusplus
#include <cmath>
#include <list>
#include <mutex>
#include <string>
#include <tuple>
#include <atomic>
#include <chrono>
#include <memory>
#include <thread>
#include <tuple>
#include <vector>
#include <unordered_map>
#include <utility>

#include "common/assert.h"
#include "common/logging/log.h"
#include "common/math_util.h"
#include "common/param_package.h"
#include "common/vector_math.h"
#include "input_common/main.h"
#include "input_common/sdl/sdl.h"
#endif

namespace InputManager {

static std::shared_ptr<ButtonFactory> button;
static std::shared_ptr<AnalogFactory> analog;
static std::shared_ptr<MotionFactory> motion;

// Button Handler
class KeyButton final : public Input::ButtonDevice {
public:
    explicit KeyButton(std::shared_ptr<ButtonList> button_list_) : button_list(button_list_) {}
    
    ~KeyButton();
    
    bool GetStatus() const override {
        return status.load();
    }
    
    friend class ButtonList;
    
private:
    std::shared_ptr<ButtonList> button_list;
    std::atomic<bool> status{false};
};

struct KeyButtonPair {
    int button_id;
    KeyButton* key_button;
};

class ButtonList {
public:
    void AddButton(int button_id, KeyButton* key_button) {
        std::lock_guard<std::mutex> guard(mutex);
        list.push_back(KeyButtonPair{button_id, key_button});
    }
    
    void RemoveButton(const KeyButton* key_button) {
        std::lock_guard<std::mutex> guard(mutex);
        list.remove_if(
                       [key_button](const KeyButtonPair& pair) { return pair.key_button == key_button; });
    }
    
    bool ChangeButtonStatus(int button_id, bool pressed) {
        std::lock_guard<std::mutex> guard(mutex);
        bool button_found = false;
        for (const KeyButtonPair& pair : list) {
            if (pair.button_id == button_id) {
                pair.key_button->status.store(pressed);
                button_found = true;
            }
        }
        // If we don't find the button don't consume the button press event
        return button_found;
    }
    
    void ChangeAllButtonStatus(bool pressed) {
        std::lock_guard<std::mutex> guard(mutex);
        for (const KeyButtonPair& pair : list) {
            pair.key_button->status.store(pressed);
        }
    }
    
private:
    std::mutex mutex;
    std::list<KeyButtonPair> list;
};

KeyButton::~KeyButton() {
    button_list->RemoveButton(this);
}

// Analog Button
class AnalogButton final : public Input::ButtonDevice {
public:
    explicit AnalogButton(std::shared_ptr<AnalogButtonList> button_list_, float threshold_,
                          bool trigger_if_greater_)
    : button_list(button_list_), threshold(threshold_),
    trigger_if_greater(trigger_if_greater_) {}
    
    ~AnalogButton();
    
    bool GetStatus() const override {
        if (trigger_if_greater)
            return axis_val.load() > threshold;
        return axis_val.load() < threshold;
    }
    
    friend class AnalogButtonList;
    
private:
    std::shared_ptr<AnalogButtonList> button_list;
    std::atomic<float> axis_val{0.0f};
    float threshold;
    bool trigger_if_greater;
};

struct AnalogButtonPair {
    int axis_id;
    AnalogButton* key_button;
};

class AnalogButtonList {
public:
    void AddAnalogButton(int button_id, AnalogButton* key_button) {
        std::lock_guard<std::mutex> guard(mutex);
        list.push_back(AnalogButtonPair{button_id, key_button});
    }
    
    void RemoveButton(const AnalogButton* key_button) {
        std::lock_guard<std::mutex> guard(mutex);
        list.remove_if(
                       [key_button](const AnalogButtonPair& pair) { return pair.key_button == key_button; });
    }
    
    bool ChangeAxisValue(int axis_id, float axis) {
        std::lock_guard<std::mutex> guard(mutex);
        bool button_found = false;
        for (const AnalogButtonPair& pair : list) {
            if (pair.axis_id == axis_id) {
                pair.key_button->axis_val.store(axis);
                button_found = true;
            }
        }
        // If we don't find the button don't consume the button press event
        return button_found;
    }
    
private:
    std::mutex mutex;
    std::list<AnalogButtonPair> list;
};

AnalogButton::~AnalogButton() {
    button_list->RemoveButton(this);
}

// Joystick Handler
class Joystick final : public Input::AnalogDevice {
public:
    explicit Joystick(std::shared_ptr<AnalogList> analog_list_) : analog_list(analog_list_) {}
    
    ~Joystick();
    
    std::tuple<float, float> GetStatus() const override {
        return std::make_tuple(x_axis.load(), y_axis.load());
    }
    
    friend class AnalogList;
    
private:
    std::shared_ptr<AnalogList> analog_list;
    std::atomic<float> x_axis{0.0f};
    std::atomic<float> y_axis{0.0f};
};

struct AnalogPair {
    int analog_id;
    Joystick* key_button;
};

class AnalogList {
public:
    void AddButton(int analog_id, Joystick* key_button) {
        std::lock_guard<std::mutex> guard(mutex);
        list.push_back(AnalogPair{analog_id, key_button});
    }
    
    void RemoveButton(const Joystick* key_button) {
        std::lock_guard<std::mutex> guard(mutex);
        list.remove_if(
                       [key_button](const AnalogPair& pair) { return pair.key_button == key_button; });
    }
    
    bool ChangeJoystickStatus(int analog_id, float x, float y) {
        std::lock_guard<std::mutex> guard(mutex);
        bool button_found = false;
        for (const AnalogPair& pair : list) {
            if (pair.analog_id == analog_id) {
                pair.key_button->x_axis.store(x);
                pair.key_button->y_axis.store(y);
                button_found = true;
            }
        }
        return button_found;
    }
    
private:
    std::mutex mutex;
    std::list<AnalogPair> list;
};

AnalogFactory::AnalogFactory() : analog_list{std::make_shared<AnalogList>()} {}

Joystick::~Joystick() {
    analog_list->RemoveButton(this);
}

ButtonFactory::ButtonFactory()
: button_list{std::make_shared<ButtonList>()}, analog_button_list{
    std::make_shared<AnalogButtonList>()} {}

std::unique_ptr<Input::ButtonDevice> ButtonFactory::Create(const Common::ParamPackage& params) {
    if (params.Has("axis")) {
        const int axis_id = params.Get("axis", 0);
        const float threshold = params.Get("threshold", 0.5f);
        const std::string direction_name = params.Get("direction", "");
        bool trigger_if_greater;
        if (direction_name == "+") {
            trigger_if_greater = true;
        } else if (direction_name == "-") {
            trigger_if_greater = false;
        } else {
            trigger_if_greater = true;
            LOG_ERROR(Input, "Unknown direction {}", direction_name);
        }
        std::unique_ptr<AnalogButton> analog_button =
        std::make_unique<AnalogButton>(analog_button_list, threshold, trigger_if_greater);
        analog_button_list->AddAnalogButton(axis_id, analog_button.get());
        return std::move(analog_button);
    }
    
    int button_id = params.Get("code", 0);
    std::unique_ptr<KeyButton> key_button = std::make_unique<KeyButton>(button_list);
    button_list->AddButton(button_id, key_button.get());
    return std::move(key_button);
}

bool ButtonFactory::PressKey(int button_id) {
    return button_list->ChangeButtonStatus(button_id, true);
}

bool ButtonFactory::ReleaseKey(int button_id) {
    return button_list->ChangeButtonStatus(button_id, false);
}

bool ButtonFactory::AnalogButtonEvent(int axis_id, float axis_val) {
    return analog_button_list->ChangeAxisValue(axis_id, axis_val);
}

std::unique_ptr<Input::AnalogDevice> AnalogFactory::Create(const Common::ParamPackage& params) {
    int analog_id = params.Get("code", 0);
    std::unique_ptr<Joystick> analog = std::make_unique<Joystick>(analog_list);
    analog_list->AddButton(analog_id, analog.get());
    return std::move(analog);
}

bool AnalogFactory::MoveJoystick(int analog_id, float x, float y) {
    return analog_list->ChangeJoystickStatus(analog_id, x, y);
}

namespace {
using Common::Vec3;
}

class Motion : public Input::MotionDevice {
    std::chrono::microseconds update_period;
    
    mutable std::atomic<Vec3<float>> acceleration{};
    mutable std::atomic<Vec3<float>> rotation{};
    static_assert(decltype(acceleration)::is_always_lock_free, "vectors are not lock free");
    std::thread poll_thread;
    std::atomic<bool> stop_polling = false;
    
    CMMotionManager *motionManager;
    
    static Vec3<float> TransformAxes(Vec3<float> in) {
        // 3DS   Y+            Phone     Z+
        // on    |             laying    |
        // table |             in        |
        //       |_______ X-   portrait  |_______ X+
        //      /              mode     /
        //     /                       /
        //    Z-                      Y-
        Vec3<float> out;
        out.y = in.z;
        // rotations are 90 degrees counter-clockwise from portrait
        switch (screen_rotation) {
            case 0:
                out.x = -in.x;
                out.z = in.y;
                break;
            case 1:
                out.x = in.y;
                out.z = in.x;
                break;
            case 2:
                out.x = in.x;
                out.z = -in.y;
                break;
            case 3:
                out.x = -in.y;
                out.z = -in.x;
                break;
            default:
                UNREACHABLE();
        }
        return out;
    }
    
public:
    Motion(std::chrono::microseconds update_period_, bool asynchronous = false)
    : update_period(update_period_) {
        if (asynchronous) {
            poll_thread = std::thread([this] {
                Construct();
                auto start = std::chrono::high_resolution_clock::now();
                while (!stop_polling) {
                    Update();
                    std::this_thread::sleep_until(start += update_period);
                }
                Destruct();
            });
        } else {
            Construct();
        }
    }
    
//    std::tuple<Vec3<float>, Vec3<float>> GetStatus() const override {
//        if (std::thread::id{} == poll_thread.get_id()) {
//            Update();
//        }
//        return {acceleration, rotation};
//    }
    
    mutable Vec3<float> smoothed_accel{0, 0, 0};
    mutable Vec3<float> smoothed_rotation{0, 0, 0};

    const float smoothingFactor = 0.1f; // 越小越平滑
    const float deadZone = 0.05f;

    Vec3<float> ApplySmoothing(const Vec3<float>& prev, const Vec3<float>& current) const {
        return {
            prev.x + (current.x - prev.x) * smoothingFactor,
            prev.y + (current.y - prev.y) * smoothingFactor,
            prev.z + (current.z - prev.z) * smoothingFactor
        };
    }

    Vec3<float> ApplyDeadZone(const Vec3<float>& v) const {
        return {
            std::abs(v.x) < deadZone ? 0.0f : v.x,
            std::abs(v.y) < deadZone ? 0.0f : v.y,
            std::abs(v.z) < deadZone ? 0.0f : v.z
        };
    }

    std::tuple<Vec3<float>, Vec3<float>> GetStatus() const override {
        CMDeviceMotion *motion = [motionManager deviceMotion];
        CMAttitude *attitude = motion.attitude;
        CMRotationMatrix r = attitude.rotationMatrix;

        const float RAD_TO_DEG = 180.0f / M_PI;

        float gx = static_cast<float>(motion.gravity.x);
        float gy = static_cast<float>(motion.gravity.y);
        float gz = static_cast<float>(motion.gravity.z);

        Vec3<float> worldGravity = {
            static_cast<float>(r.m11 * gx + r.m12 * gy + r.m13 * gz),
            static_cast<float>(r.m21 * gx + r.m22 * gy + r.m23 * gz),
            static_cast<float>(r.m31 * gx + r.m32 * gy + r.m33 * gz)
        };

        Vec3<float> raw_accel = {
            -worldGravity.x,
            -worldGravity.y,
            -worldGravity.z
        };

        Vec3<float> raw_rotation = {
            static_cast<float>(motion.rotationRate.x * RAD_TO_DEG),
            static_cast<float>(motion.rotationRate.y * RAD_TO_DEG),
            static_cast<float>(motion.rotationRate.z * RAD_TO_DEG)
        };

        // 平滑处理
        smoothed_accel = ApplySmoothing(smoothed_accel, raw_accel);
        smoothed_rotation = ApplySmoothing(smoothed_rotation, raw_rotation);

        // 死区处理
        Vec3<float> final_accel = ApplyDeadZone(smoothed_accel);
        Vec3<float> final_rotation = ApplyDeadZone(smoothed_rotation);

        return {final_accel, final_rotation};
    }
    
    void Construct() {
        motionManager = [[CMMotionManager alloc] init];
        EnableSensors();
    }
    
    void Destruct() {
        [motionManager stopDeviceMotionUpdates];
        motionManager = NULL;
    }
    
    void Update() const {
        CMDeviceMotion *motion = [motionManager deviceMotion];
        
        Vec3<float> new_accel{}, new_gyro{};
        new_accel = {
            static_cast<float>(motion.gravity.x + motion.userAcceleration.x),
            static_cast<float>(motion.gravity.y + motion.userAcceleration.y),
            static_cast<float>(motion.gravity.z + motion.userAcceleration.z)
        };
        
        new_gyro = {
            static_cast<float>(-motion.rotationRate.x),
            static_cast<float>(motion.rotationRate.y),
            static_cast<float>(motion.rotationRate.z)
        };
        
        rotation = new_gyro * 180.f / static_cast<float>(M_PI);
    }
    
    void DisableSensors() {
        [motionManager stopDeviceMotionUpdates];
    }
    
    void EnableSensors() {
        [motionManager startDeviceMotionUpdates];
    }
};

std::unique_ptr<Input::MotionDevice> MotionFactory::Create(const Common::ParamPackage &params) {
    std::chrono::milliseconds update_period{params.Get("update_period", 4)};
    std::unique_ptr<Motion> motion = std::make_unique<Motion>(update_period);
    _motion = motion.get();
    return std::move(motion);
}

void MotionFactory::EnableSensors() {
    _motion->EnableSensors();
};

void MotionFactory::DisableSensors() {
    _motion->DisableSensors();
};

ButtonFactory* ButtonHandler() {
    return button.get();
}

AnalogFactory* AnalogHandler() {
    return analog.get();
}

MotionFactory* MotionHandler() {
    return motion.get();
}

std::string GenerateButtonParamPackage(int button) {
    Common::ParamPackage param{
        {"engine", "gamepad"},
        {"code", std::to_string(button)},
    };
    return param.Serialize();
}

std::string GenerateAnalogButtonParamPackage(int axis, float axis_val) {
    Common::ParamPackage param{
        {"engine", "gamepad"},
        {"axis", std::to_string(axis)},
    };
    if (axis_val > 0) {
        param.Set("direction", "+");
        param.Set("threshold", "0.5");
    } else {
        param.Set("direction", "-");
        param.Set("threshold", "-0.5");
    }
    
    return param.Serialize();
}

std::string GenerateAnalogParamPackage(int axis_id) {
    Common::ParamPackage param{
        {"engine", "gamepad"},
        {"code", std::to_string(axis_id)},
    };
    return param.Serialize();
}

void Init() {
    button = std::make_shared<ButtonFactory>();
    analog = std::make_shared<AnalogFactory>();
    motion = std::make_shared<MotionFactory>();
    Input::RegisterFactory<Input::ButtonDevice>("gamepad", button);
    Input::RegisterFactory<Input::AnalogDevice>("gamepad", analog);
    Input::RegisterFactory<Input::MotionDevice>("motion_emu", motion);
}

void Shutdown() {
    Input::UnregisterFactory<Input::ButtonDevice>("gamepad");
    Input::UnregisterFactory<Input::AnalogDevice>("gamepad");
    Input::UnregisterFactory<Input::MotionDevice>("motion_emu");
    button.reset();
    analog.reset();
    motion.reset();
}

} // namespace InputManager
