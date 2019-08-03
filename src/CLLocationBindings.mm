#include <math.h>
#include <node.h>
#include <v8.h>

#import "LocationManager.h"

using namespace v8;
using namespace node;

void getCurrentPosition(const FunctionCallbackInfo<Value>& args) {
  Isolate* isolate = args.GetIsolate();
  HandleScope scope(isolate);

  LocationManager* locationManager = [[LocationManager alloc] init];

  Local<Context> context = Context::New(isolate);

  if (args.Length() == 1) {
    if (args[0]->IsObject()) {
      Local<Object> options = args[0]->ToObject(context).ToLocalChecked();

      Local<String> maximumAgeKey = String::NewFromUtf8(isolate, "maximumAge");
      if (options->Has(context, maximumAgeKey).FromMaybe(false)) {
        // Anything less than 100ms doesn't make any sense
        locationManager.maximumAge = fmax(
          100, options->Get(maximumAgeKey)->NumberValue(context).ToChecked()
        );
        locationManager.maximumAge /= 1000.0;
      }

      Local<String> enableHighAccuracyKey = String::NewFromUtf8(
        isolate, "enableHighAccuracy"
      );
      if (options->Has(context, enableHighAccuracyKey).FromMaybe(false)) {
        locationManager.enableHighAccuracy = options->Get(
          enableHighAccuracyKey
        )->BooleanValue(context).ToChecked();
      }

      Local<String> timeout = String::NewFromUtf8(
        isolate, "timeout"
      );
      if (options->Has(context, timeout).FromMaybe(false)) {
        locationManager.timeout = options->Get(timeout)->NumberValue(context).ToChecked();
      }

    }
  }

  if (![CLLocationManager locationServicesEnabled]) {
    isolate->ThrowException(
      Exception::TypeError(
        String::NewFromUtf8(isolate, "CLocationErrorNoLocationService")
      )
    );
    return;
  }

  CLLocation* location = [locationManager getCurrentLocation];

  if ([locationManager hasFailed]) {
    switch (locationManager.errorCode) {
      case kCLErrorDenied:
        isolate->ThrowException(
            Exception::TypeError(
              String::NewFromUtf8(
                isolate,
                "CLocationErrorLocationServiceDenied"
              )
            )
        );
        return;
      case kCLErrorGeocodeCanceled:
        isolate->ThrowException(
            Exception::TypeError(
              String::NewFromUtf8(isolate, "CLocationErrorGeocodeCanceled")
            )
        );
        return;
      case kCLErrorLocationUnknown:
        isolate->ThrowException(
            Exception::TypeError(
              String::NewFromUtf8(isolate, "CLocationErrorLocationUnknown")
            )
        );
        return;
      default:
        isolate->ThrowException(
            Exception::TypeError(
              String::NewFromUtf8(isolate, "CLocationErrorLookupFailed")
            )
        );
        return;
      }
  }

  Local<Object> obj = Object::New(isolate);
  obj->Set(
    String::NewFromUtf8(isolate, "latitude"),
    Number::New(isolate, location.coordinate.latitude)
  );
  obj->Set(
    String::NewFromUtf8(isolate, "longitude"),
    Number::New(isolate, location.coordinate.longitude)
  );
  obj->Set(
    String::NewFromUtf8(isolate, "altitude"),
    Number::New(isolate, location.altitude)
  );
  obj->Set(
    String::NewFromUtf8(isolate, "horizontalAccuracy"),
    Number::New(isolate, location.horizontalAccuracy)
  );
  obj->Set(
    String::NewFromUtf8(isolate, "verticalAccuracy"),
    Number::New(isolate, location.verticalAccuracy)
  );

  NSTimeInterval seconds = [location.timestamp timeIntervalSince1970];
  obj->Set(
    String::NewFromUtf8(isolate, "timestamp"),
    Number::New(isolate, (NSInteger)ceil(seconds * 1000))
  );

  args.GetReturnValue().Set(obj);
}

void Initialise(Local<Object> exports) {
  NODE_SET_METHOD(exports, "getCurrentPosition", getCurrentPosition);
}

NODE_MODULE(macos_clocation_wrapper, Initialise)
