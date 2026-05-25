using UnityEngine;

public class TimecapsuleManager : MonoBehaviour
{
    private TimecapsuleAR _ar;

    void Start()
    {
        _ar = FindObjectOfType<TimecapsuleAR>();
    }

    // Flutter ¡æ Unity: postMessage('TimecapsuleManager', 'SpawnCapsule', id)
    public void SpawnCapsule(string capsuleId)
    {
        Debug.Log("SpawnCapsule forwarding: " + capsuleId);
        _ar?.SpawnCapsule(capsuleId);
    }

    // Flutter ¡æ Unity: postMessage('TimecapsuleManager', 'BuryCapsule', '')
    public void BuryCapsule(string message)
    {
        _ar?.BuryCapsule(message);
    }
}
