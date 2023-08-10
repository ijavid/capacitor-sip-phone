package ch.nadlo.oss.capacitor.sip_phone;

import android.content.Context;
import android.content.Intent;

public interface SipPhoneEventListener {
    void onAccountStateChanged();
    void onCallStateChanged();

    void onSipPushReceived(Context context, Intent intent);
}
